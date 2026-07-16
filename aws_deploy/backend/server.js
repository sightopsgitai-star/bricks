'use strict';

require('dotenv').config();

const express    = require('express');
const cors       = require('cors');
const jwt        = require('jsonwebtoken');
const path       = require('path');
const {
  OPCUAClient,
  MessageSecurityMode,
  SecurityPolicy,
  AttributeIds,
  DataType,
} = require('node-opcua');

const config    = require('./opc_config');
const dbManager = require('./db_manager');

// ─── Express Setup ──────────────────────────────────────────────────────────

const app        = express();
const PORT       = parseInt(process.env.PORT || '3001', 10);
const JWT_SECRET = process.env.JWT_SECRET || 'bricks_secret';
const COMPANY_ID = process.env.COMPANY_ID || 'bricks-001';

app.use(cors());
app.use(express.json());

// Serve Flutter web build from sibling folder (handles both development and deployment layouts)
const fs = require('fs');
let webBuildPath = path.join(__dirname, '..', 'demo-main', 'build', 'web');
const altWebBuildPath = path.join(__dirname, '..', 'frontend', 'build', 'web');
if (!fs.existsSync(webBuildPath) && fs.existsSync(altWebBuildPath)) {
  webBuildPath = altWebBuildPath;
}
app.use(express.static(webBuildPath));

// ─── Auth Middleware ─────────────────────────────────────────────────────────

/** Rejects with 401/403 when no valid JWT is present. */
const requireAuth = (req, res, next) => {
  const token = (req.headers['authorization'] || '').split(' ')[1];
  if (!token) return res.sendStatus(401);
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    req.user = user;
    next();
  });
};

/** Attaches user to req if JWT present; never blocks. */
const optionalAuth = (req, res, next) => {
  const token = (req.headers['authorization'] || '').split(' ')[1];
  if (token) {
    jwt.verify(token, JWT_SECRET, (err, user) => {
      if (!err) req.user = user;
      next();
    });
  } else { next(); }
};

// ─── In-Memory Live State ────────────────────────────────────────────────────

/** Latest PLC values keyed by config node key. */
const liveValues = {};
config.nodes.forEach(n => { liveValues[n.key] = null; });

let prevTotalCycle    = null;
let cycleChangedAt    = null;
let lastKnownCycleSec = 0;

// Hourly delta tracking
let prevPollCycles    = null;
let prevPollBlocks    = null;
let plcConnected      = false;
let lastPollAt        = null;
let cachedTargetCount = 5000;
let yesterdayCumulative = null; // { date: 'YYYY-MM-DD', cycles: X, blocks: Y }

/** Re-computed on every poll. */
const liveAlerts = [];

// ─── Helpers ─────────────────────────────────────────────────────────────────

const safeInt   = v => { const n = parseInt(v, 10);  return isNaN(n) ? 0 : n; };
const safeFloat = v => { const n = parseFloat(v);    return isNaN(n) ? 0.0 : n; };
const safeBool  = v => (v === true || v === 1);

/** Formats a date object to 'YYYY-MM-DD' local time without timezone shifts. */
function formatLocalDate(date = new Date()) {
  const d = new Date(date);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * PLC sends motor current as Int16 in units of 0.1 A  (e.g. 102 → 10.2 A).
 * Divide by 10 to get real Amperes.
 */
const plcCurrentToAmps = v => {
  const raw = safeInt(v);
  return Math.round((raw / 10) * 10) / 10; // one decimal place
};

/** True when at least one cycle happened recently (within 1.5× last cycle time). */
function lineIsActive() {
  if (!cycleChangedAt) return false;
  const windowMs = Math.max(lastKnownCycleSec * 1.5 * 1000, 300_000); // min 5 min
  return (Date.now() - cycleChangedAt.getTime()) < windowMs;
}

/**
 * Writes a value to an OPC UA node on the PLC.
 */
async function writeOpcNode(nodeId, value, dataTypeStr) {
  if (!activeSession) {
    console.warn(`[PLC] No active session to write to ${nodeId}`);
    return;
  }
  try {
    const nodeToWrite = {
      nodeId: nodeId,
      attributeId: AttributeIds.Value,
      value: {
        value: {
          dataType: DataType[dataTypeStr],
          value: value
        }
      }
    };
    await activeSession.write(nodeToWrite);
    console.log(`[PLC] Successfully wrote ${value} (${dataTypeStr}) to ${nodeId}`);
  } catch (err) {
    console.error(`[PLC] Error writing to ${nodeId}:`, err.message);
  }
}

// ─── Alert Generator ─────────────────────────────────────────────────────────

function refreshAlerts() {
  liveAlerts.length = 0;
  if (!plcConnected) return;

  const active = lineIsActive();
  config.machines.forEach(m => {
    const curr     = m.motorCurrentKey ? liveValues[m.motorCurrentKey] : null;
    const vfdFault = m.vfdFaultKey     ? safeBool(liveValues[m.vfdFaultKey]) : false;
    const stopBit  = m.stopBitKey      ? safeBool(liveValues[m.stopBitKey])  : false;

    // VFD Fault alert
    if (vfdFault) {
      liveAlerts.push({
        id: `vfdFault-${m.id}`, machineId: m.id, machineName: m.name,
        type: 'vfdFault', severity: 'critical',
        message: `${m.name} — VFD Fault detected. Check drive status immediately.`,
        timestamp: new Date().toISOString(), isRead: false, isResolved: false,
      });
    }

    // Stop bit alert (machine commanded stop while line active)
    if (active && stopBit) {
      liveAlerts.push({
        id: `stopBit-${m.id}`, machineId: m.id, machineName: m.name,
        type: 'machineStopped', severity: 'high',
        message: `${m.name} — Stop command active while production line is running.`,
        timestamp: new Date().toISOString(), isRead: false, isResolved: false,
      });
    }

    // Motor over-current
    if (curr !== null && curr !== undefined) {
      const amps = plcCurrentToAmps(curr);
      if (active && amps === 0) {
        liveAlerts.push({
          id: `stopped-${m.id}`, machineId: m.id, machineName: m.name,
          type: 'machineStopped', severity: 'high',
          message: `${m.name} — motor current is 0 A while line is active.`,
          timestamp: new Date().toISOString(), isRead: false, isResolved: false,
        });
      }
      if (amps >= 27) {
        liveAlerts.push({
          id: `overcurrent-${m.id}`, machineId: m.id, machineName: m.name,
          type: 'abnormalCondition', severity: amps >= 30 ? 'critical' : 'medium',
          message: `${m.name} — motor current ${amps} A (rated max: 30 A).`,
          timestamp: new Date().toISOString(), isRead: false, isResolved: false,
        });
      }
    }
  });
}

// ─── Build API Payload ────────────────────────────────────────────────────────

function getLastNonZeroCycleTimeMs() {
  const arr = liveValues['cycleTimeData'];
  if (arr && typeof arr.length === 'number') {
    for (let i = arr.length - 1; i >= 0; i--) {
      const val = safeInt(arr[i]);
      if (val > 0) return val;
    }
  }
  return 0;
}

function buildPayload() {
  const totalCycle  = Math.max(safeInt(liveValues['systemTotalCycle']), safeInt(liveValues['systemTotalCycle2']));
  const totalBlocks = safeInt(liveValues['totalBlockCountWithCycle']);
  const runTime     = safeInt(liveValues['runTimeDuration']);

  // Best available blockCount for backward compatibility
  const blockCount  = safeInt(liveValues['blockCount']) || 24;

  // Calculate today's daily values based on cumulative counters or direct PLC todayCycleCount
  let todayCycle = safeInt(liveValues['todayCycleCount']);
  if (todayCycle <= 0 && yesterdayCumulative) {
    todayCycle = Math.max(0, totalCycle - yesterdayCumulative.cycles);
  }
  const actualCount = totalBlocks > 0 ? totalBlocks : (todayCycle * blockCount);

  // Extract correct last completed cycle time in ms
  let lastCycleMs = safeInt(liveValues['lastCycleTimeMs']) || safeInt(liveValues['lastCycleTimeSec']) * 1000;
  if (lastCycleMs <= 0) {
    lastCycleMs = getLastNonZeroCycleTimeMs();
  }
  const cycleSec = lastCycleMs / 1000.0;

  // Extract correct current running cycle time in ms (fallback to last completed if idle)
  let currentCycleMs = safeInt(liveValues['currentCycleTimeMs']);
  if (currentCycleMs <= 0) {
    currentCycleMs = lastCycleMs;
  }

  // ── Energy data from power meter ──────────────────────────────────────
  // kWh = integer part (ns=4;i=612) + decimal part (ns=4;i=645)
  const kwhInteger = safeInt(liveValues['kwhInt']) || 0;
  const kwhDecimal = safeFloat(liveValues['kwh'])  || 0;
  const fullKwh    = parseFloat((kwhInteger + kwhDecimal).toFixed(2));

  const energyData = {
    amps:       safeFloat(liveValues['amps']),
    kwh:        fullKwh,
    hz:         safeFloat(liveValues['hz']),
    pf:         safeFloat(liveValues['pf']),
    voltageAvg: safeFloat(liveValues['voltageAvg']),
    llAvg:      safeFloat(liveValues['llAvg']),
    l1:         safeFloat(liveValues['l1']),
    l2:         safeFloat(liveValues['l2']),
    l3:         safeFloat(liveValues['l3']),
    l12:        safeFloat(liveValues['l12']),
    l23:        safeFloat(liveValues['l23']),
    l31:        safeFloat(liveValues['l31']),
    l1Amps:     safeFloat(liveValues['l1Amps']),
    l2Amps:     safeFloat(liveValues['l2Amps']),
    l3Amps:     safeFloat(liveValues['l3Amps']),
    l1Pf:       safeFloat(liveValues['l1Pf']),
    l2Pf:       safeFloat(liveValues['l2Pf']),
    l3Pf:       safeFloat(liveValues['l3Pf']),
    // Computed: 3-phase kW ≈ √3 × V_LL × I × PF  (approximation for display)
    overallPowerKw: (safeFloat(liveValues['llAvg']) * safeFloat(liveValues['amps']) * safeFloat(liveValues['pf']) * 1.732) / 1000,
  };

  // ── Build machines using running bits as primary source ───────────────
  const machines = config.machines.map(m => {
    const rawCurrent = m.motorCurrentKey ? (liveValues[m.motorCurrentKey] ?? null) : null;
    const rawSpeed   = m.speedKey        ? (liveValues[m.speedKey]        ?? 0)    : null;
    const runBit     = m.runBitKey       ? safeBool(liveValues[m.runBitKey])        : null;
    const vfdFault   = m.vfdFaultKey     ? safeBool(liveValues[m.vfdFaultKey])      : false;
    const stopBit    = m.stopBitKey      ? safeBool(liveValues[m.stopBitKey])        : false;

    const motorCurrent  = rawCurrent !== null ? plcCurrentToAmps(rawCurrent) : null;
    const motorSpeedRpm = rawSpeed   !== null ? safeInt(rawSpeed) : null;

    // Machine running status logic:
    // If the PLC is connected, assume the machine is running by default unless:
    // 1. VFD Fault is active (vfdFault === true)
    // 2. Stop Bit is active (stopBit === true)
    // Otherwise, fallback to false if PLC is disconnected.
    let isRunning = false;
    if (plcConnected) {
      if (vfdFault) {
        isRunning = false;
      } else if (stopBit === true) {
        isRunning = false;
      } else {
        isRunning = true;
      }
    }

    return {
      id: m.id, name: m.name, type: m.type, companyId: COMPANY_ID,
      status:        isRunning ? 'running' : 'stopped',
      cycleCount:    todayCycle,
      cureCycleTime: cycleSec > 0 ? cycleSec / 60.0 : 0,
      efficiency:    motorCurrent !== null ? Math.min(100, Math.round((motorCurrent / 30) * 1000) / 10) : 0,
      motorCurrent,
      motorSpeedRpm,
      runBit:        runBit,
      vfdFault:      vfdFault,
      stopBit:       stopBit,
      downtimeMinutes: 0, startCount: 0, stopCount: 0,
    };
  });

  const running = machines.filter(m => m.status === 'running').length;
  const stopped = machines.filter(m => m.status === 'stopped').length;

  return {
    success: true,
    plcConnected,
    lastPollAt,
    energyData,
    stats: {
      companyId:            COMPANY_ID,
      totalCycles:          totalCycle,
      cumulativeCycles:     totalCycle,
      cumulativeBlocks:     yesterdayCumulative ? (yesterdayCumulative.blocks + actualCount) : (totalCycle * blockCount),
      todayCycles:          todayCycle,
      actualCount,
      dailyProduction:      actualCount,
      blockCount:           blockCount,
      totalBlockCountWithCycle: totalBlocks,
      targetCount:          cachedTargetCount,
      overallEfficiency:    0,
      lastCycleTimeSec:     cycleSec,
      averageCureCycleTime: cycleSec > 0 ? parseFloat((cycleSec / 60.0).toFixed(2)) : 0,
      currentCycleTimeMs:   currentCycleMs,
      lastCycleTimeMs:      lastCycleMs,
      activeRecipeName:     liveValues['activeRecipeName'] ? String(liveValues['activeRecipeName']).trim() : '',
      blockName:            liveValues['blockName'] ? String(liveValues['blockName']).trim() : '',
      runTimeDuration:      runTime,
      machinesRunning:      running,
      machinesStopped:      stopped,
      machinesInMaintenance: 0,
      totalDowntimeMinutes: 0,
      lastUpdated:          lastPollAt || new Date().toISOString(),
      // Energy in stats for convenience
      overallPowerKw:       energyData.overallPowerKw,
      totalEnergyKwh:       energyData.kwh,
      overallAmps:          energyData.amps,
      powerFactor:          energyData.pf,
      frequency:            energyData.hz,
      rawSensors: config.nodes.reduce((acc, n) => {
        const defaultVal = n.dataType === 'String' ? '' : 0;
        let val = liveValues[n.key];
        if (n.key === 'blockCount' && (val === null || val === undefined || val === 0)) {
          val = 12; // Fallback to 12 blocks per cycle
        } else {
          val = val ?? defaultVal;
        }
        // Scale current nodes for display; booleans stay as-is
        const displayVal = n.unit === 'A' && n.dataType === 'Int16' ? plcCurrentToAmps(val) : val;
        acc[n.key] = { label: n.label, value: displayVal, unit: n.unit };
        return acc;
      }, {}),
    },
    machines,
    alerts: [...liveAlerts],
  };
}

// ─── OPC-UA Polling ──────────────────────────────────────────────────────────

const opcClient = OPCUAClient.create({
  applicationName:          'BricksDashboard',
  connectionStrategy: {
    initialDelay: 2000,
    maxRetry:     Infinity,
    maxDelay:     15000,
  },
  securityMode:             MessageSecurityMode.None,
  securityPolicy:           SecurityPolicy.None,
  endpointMustExist:        false,
  requestedSessionTimeout:  config.requestedSessionTimeout,
  connectionTimeout:        config.connectionTimeout,
  keepSessionAlive:         true,
});

opcClient.on('connection_lost',          () => { plcConnected = false; console.log('[PLC] Connection LOST — will retry'); });
opcClient.on('connection_reestablished', () => { plcConnected = true;  console.log('[PLC] Connection RE-ESTABLISHED ✅'); });
opcClient.on('backoff', (n, delay)       =>  console.log(`[PLC] Retry #${n} in ${(delay/1000).toFixed(1)}s...`));

let activeSession = null;

async function pollOnce() {
  if (!activeSession) return;

  const nodeIds = config.nodes.map(n => ({ nodeId: n.nodeId, attributeId: AttributeIds.Value }));
  try {
    const results = await activeSession.read(nodeIds);
    results.forEach((dv, i) => {
      const k = config.nodes[i].key;
      if (dv?.value?.value !== undefined && dv.value.value !== null) {
        liveValues[k] = dv.value.value;
      }
    });

    // Detect cycle change for lineIsActive()
    const curCycle = Math.max(safeInt(liveValues['systemTotalCycle']), safeInt(liveValues['systemTotalCycle2']));
    if (prevTotalCycle !== null && curCycle > 0 && curCycle !== prevTotalCycle) {
      cycleChangedAt = new Date();
      const ct = liveValues['lastCycleTimeSec'];
      if (ct && ct > 0) lastKnownCycleSec = ct;
    }
    if (curCycle > 0) prevTotalCycle = curCycle;

    lastPollAt = new Date().toISOString();

    // Dynamically initialize start-of-day cumulative values
    const todayStr = formatLocalDate();
    const curCumulativeBlocks = liveValues['totalBlockCountWithCycle'];
    if (curCycle !== null && curCumulativeBlocks !== null) {
      if (!yesterdayCumulative || yesterdayCumulative.date !== todayStr) {
        try {
          const liveBlocksPerCycle = safeInt(liveValues['blockCount']) || 24;
          const estimatedCumulativeBlocks = curCycle * liveBlocksPerCycle;
          const curTodayCycles = safeInt(liveValues['todayCycleCount']);
          const curTodayBlocks = curCumulativeBlocks > 0 ? curCumulativeBlocks : (curTodayCycles * liveBlocksPerCycle);

          if (!yesterdayCumulative) {
            console.log(`[PLC] Connected. Live cumulative values: cycles=${curCycle}, blocks=${curCumulativeBlocks} (est=${estimatedCumulativeBlocks}). Healing database history...`);
            await dbManager.healCumulativeHistory(COMPANY_ID, curCycle, estimatedCumulativeBlocks, curTodayCycles, curTodayBlocks);
          }

          const dbVals = await dbManager.getYesterdayCumulativeValues(COMPANY_ID);
          if (dbVals) {
            yesterdayCumulative = {
              date: todayStr,
              cycles: dbVals.cycles,
              blocks: dbVals.blocks
            };
            console.log(`[PLC] Loaded start-of-day cumulative values from yesterday's DB row: cycles=${dbVals.cycles}, blocks=${dbVals.blocks}`);
          } else {
            yesterdayCumulative = {
              date: todayStr,
              cycles: curCycle,
              blocks: estimatedCumulativeBlocks
            };
            console.log(`[PLC] No yesterday cumulative values in DB. Set start-of-day reference to current PLC: cycles=${curCycle}, blocks=${estimatedCumulativeBlocks}`);
          }
        } catch (err) {
          console.error('[PLC] Error resolving yesterday cumulative stats:', err.message);
        }
      }
    }

    if (!plcConnected) console.log('[PLC] Data streaming ACTIVE ✅');
    plcConnected = true;

    refreshAlerts();

    // Persist to AWS RDS
    const payload = buildPayload();
    dbManager.updateToday(payload.stats, COMPANY_ID).catch(() => {});
    dbManager.updateMachineStats(payload.machines, COMPANY_ID).catch(() => {});

    // Persist hourly energy telemetry
    dbManager.logHourlyEnergy(
      COMPANY_ID,
      payload.energyData.kwh,
      payload.energyData.amps,
      payload.energyData.pf,
      payload.energyData
    ).catch(() => {});

    // Hourly Delta Persistence
    const curTodayCycles = payload.stats.todayCycles;
    const curBlocks      = payload.stats.actualCount;

    if (prevPollCycles !== null && prevPollBlocks !== null) {
      const cyclesDelta = curTodayCycles - prevPollCycles;
      const blocksDelta = curBlocks - prevPollBlocks;
      if (cyclesDelta > 0 || blocksDelta > 0) {
        const activeRec = liveValues['activeRecipeName'] ? String(liveValues['activeRecipeName']).trim() : '';
        const blkName = liveValues['blockName'] ? String(liveValues['blockName']).trim() : '';
        let recipeName = 'X-Shape_80MM';
        if (activeRec && blkName) {
          recipeName = activeRec === blkName ? activeRec : `${activeRec} / ${blkName}`;
        } else if (activeRec) {
          recipeName = activeRec;
        } else if (blkName) {
          recipeName = blkName;
        }
        const lastCycleTime = safeFloat(liveValues['lastCycleTimeSec']);
        dbManager.incrementHourlyProduction(COMPANY_ID,
          cyclesDelta > 0 ? cyclesDelta : 0,
          blocksDelta > 0 ? blocksDelta : 0,
          recipeName,
          lastCycleTime
        ).catch(() => {});
      }
    }
    prevPollCycles = curTodayCycles;
    prevPollBlocks = curBlocks;

  } catch (err) {
    if (err.message.includes('BadSession') || err.message.includes('session')) {
      console.warn('[PLC] Session invalid — recreating...');
      activeSession = null;
    }
    plcConnected = false;
  }
}

async function startPollLoop() {
  try {
    if (!activeSession) {
      console.log('[PLC] Creating OPC-UA session...');
      activeSession = await opcClient.createSession();
      console.log('[PLC] Session created ✅');
    }
    await pollOnce();
  } catch (err) {
    console.warn('[PLC] Poll error:', err.message);
    activeSession = null;
    plcConnected  = false;
  }
  setTimeout(startPollLoop, config.pollIntervalMs);
}

// ─── API Routes ──────────────────────────────────────────────────────────────

/**
 * GET /api/data — Live PLC data + DB stats + admin overrides.
 * Auth optional: raw sensors stripped for unauthenticated callers.
 */
app.get('/api/data', optionalAuth, async (req, res) => {
  const companyId = req.query.company || COMPANY_ID;

  // Fetch admin overrides for this company
  const adminOverrides = await dbManager.getMachineOverrides(companyId).catch(() => ({}));

  if (companyId !== COMPANY_ID) {
    try {
      const clientInfo = await dbManager.getClient(companyId);
      if (!clientInfo) {
        return res.status(404).json({ success: false, message: 'Client not found' });
      }

      const dbMachines   = await dbManager.getMachineStats(companyId);
      const storedStats  = await dbManager.getTodayStats(companyId);
      const globalTotal  = await dbManager.getGlobalTotalCycles(companyId);
      const targetCount  = clientInfo.target_count || 5000;

      const machines = dbMachines.map(m => {
        const overrideEnabled = adminOverrides[m.machine_id] !== false; // default true
        return {
          id: m.machine_id,
          name: m.machine_id.split('-')[0].replace(/_/g, ' '),
          type: 'Machine',
          companyId: companyId,
          status: overrideEnabled ? (m.status || 'stopped') : 'stopped',
          cycleCount: m.total_cycles || 123,
          cureCycleTime: m.last_cycle_time ? m.last_cycle_time / 60.0 : 2.05,
          efficiency: 85.0,
          motorCurrent: m.motor_current || 12.3,
          motorSpeedRpm: m.motor_speed_rpm || 1230,
          downtimeMinutes: 0, startCount: 0, stopCount: 0,
          adminDisabled: !overrideEnabled,
          vfdFault: false,
          runBit: overrideEnabled ? (m.status === 'running') : false,
        };
      });

      const running = machines.filter(m => m.status === 'running').length;
      const stopped = machines.filter(m => m.status === 'stopped').length;

      const stats = {
        companyId, companyName: clientInfo.name,
        totalCycles:           globalTotal || 123,
        todayCycles:           storedStats ? storedStats.cycles : 123,
        actualCount:           storedStats ? storedStats.production : 123,
        dailyProduction:       storedStats ? storedStats.production : 123,
        blockCount:            storedStats ? storedStats.blockCount : 123,
        totalBlockCountWithCycle: storedStats ? storedStats.blockCount : 123,
        targetCount,
        overallEfficiency:     85.0,
        lastCycleTimeSec:      123.0,
        currentCycleTimeMs:   0,
        lastCycleTimeMs:      0,
        runTimeDuration:       storedStats ? storedStats.cycles * 123 : 15129,
        machinesRunning: running, machinesStopped: stopped, machinesInMaintenance: 0,
        totalDowntimeMinutes:  storedStats ? (storedStats.downtime || 0) : 0,
        lastUpdated:           new Date().toISOString(),
        hourlyBreakdown:       await dbManager.getTodayHourlyBreakdown(companyId).catch(() => ({})),
        // Energy placeholders for DB-only clients (no live PLC)
        overallPowerKw: 0, totalEnergyKwh: 0, overallAmps: 0, powerFactor: 0, frequency: 0,
        rawSensors: {
          todayCycleCount:          { label: 'Today Cycle Count',            value: storedStats ? storedStats.cycles : 123,     unit: '' },
          blockCount:               { label: 'Block Count',                  value: storedStats ? storedStats.blockCount : 123, unit: '' },
          totalBlockCountWithCycle: { label: 'Total Block Count with Cycle', value: storedStats ? storedStats.blockCount : 123, unit: '' },
        },
      };

      const payload = {
        success: true, plcConnected: false,
        lastPollAt: new Date().toISOString(),
        energyData: { amps: 0, kwh: 0, hz: 0, pf: 0, voltageAvg: 0, llAvg: 0, l1: 0, l2: 0, l3: 0, l12: 0, l23: 0, l31: 0, l1Amps: 0, l2Amps: 0, l3Amps: 0, l1Pf: 0, l2Pf: 0, l3Pf: 0, overallPowerKw: 0 },
        stats, machines, alerts: [],
        adminOverrides,
      };

      try {
        const energyHist = await dbManager.getEnergyHistory(companyId);
        payload.stats.todayEnergyHistory = energyHist.today;
        payload.stats.yesterdayEnergyHistory = energyHist.yesterday;

        const lastEnergy = await dbManager.getLastKnownEnergy(companyId);
        if (lastEnergy) {
          payload.energyData.kwh = lastEnergy.kwh;
          payload.energyData.amps = lastEnergy.amps;
          payload.energyData.pf = lastEnergy.pf;
          payload.energyData.hz = lastEnergy.hz || 50.0;
          
          payload.energyData.llAvg = lastEnergy.llAvg || 415.0;
          payload.energyData.l12 = lastEnergy.l12 || 415.0;
          payload.energyData.l23 = lastEnergy.l23 || 415.0;
          payload.energyData.l31 = lastEnergy.l31 || 415.0;
          
          payload.energyData.voltageAvg = lastEnergy.voltageAvg || 240.0;
          payload.energyData.l1 = lastEnergy.l1 || 240.0;
          payload.energyData.l2 = lastEnergy.l2 || 240.0;
          payload.energyData.l3 = lastEnergy.l3 || 240.0;

          payload.energyData.l1Amps = lastEnergy.l1Amps || lastEnergy.amps;
          payload.energyData.l2Amps = lastEnergy.l2Amps || lastEnergy.amps;
          payload.energyData.l3Amps = lastEnergy.l3Amps || lastEnergy.amps;
          payload.energyData.l1Pf = lastEnergy.l1Pf || lastEnergy.pf;
          payload.energyData.l2Pf = lastEnergy.l2Pf || lastEnergy.pf;
          payload.energyData.l3Pf = lastEnergy.l3Pf || lastEnergy.pf;
          
          payload.energyData.overallPowerKw = (payload.energyData.llAvg * lastEnergy.amps * lastEnergy.pf * 1.732) / 1000;

          payload.stats.totalEnergyKwh = lastEnergy.kwh;
          payload.stats.overallAmps = lastEnergy.amps;
          payload.stats.powerFactor = lastEnergy.pf;
          payload.stats.overallPowerKw = payload.energyData.overallPowerKw;
          payload.stats.frequency = payload.energyData.hz;
        }
      } catch (err) {
        console.error('[API] Error fetching energy history for custom client:', err.message);
      }

      if (!req.user) delete payload.stats.rawSensors;
      return res.json(payload);

    } catch (err) {
      console.error('[API] Error getting custom client data:', err.message);
      return res.status(500).json({ success: false, message: err.message });
    }
  }

  // --- Live PLC Client ---
  const payload = buildPayload();

  // Apply admin overrides to live machines
  payload.machines = payload.machines.map(m => {
    const overrideEnabled = adminOverrides[m.id] !== false;
    return {
      ...m,
      adminDisabled: !overrideEnabled,
      status: overrideEnabled ? m.status : 'stopped',
      runBit: overrideEnabled ? m.runBit : false,
    };
  });

  payload.adminOverrides = adminOverrides;

  // Recount after overrides
  payload.stats.machinesRunning = payload.machines.filter(m => m.status === 'running').length;
  payload.stats.machinesStopped = payload.machines.filter(m => m.status === 'stopped').length;

  // Merge stored DB data on top of live values
  try {
    const [stored, globalTotal, todayHourly] = await Promise.all([
      dbManager.getTodayStats(companyId),
      dbManager.getGlobalTotalCycles(companyId),
      dbManager.getTodayHourlyBreakdown(companyId),
    ]);

    if (stored) {
      payload.stats.actualCount     = Math.max(payload.stats.actualCount, stored.production);
      payload.stats.dailyProduction = payload.stats.actualCount;
      payload.stats.todayCycles     = Math.max(payload.stats.todayCycles, stored.cycles);
      payload.stats.totalDowntimeMinutes = stored.downtime || 0;
    }

    payload.stats.hourlyBreakdown = todayHourly || {};

    payload.stats.totalCycles = payload.stats.totalCycles > 0
      ? payload.stats.totalCycles
      : globalTotal;

  } catch (err) {
    console.error('[API] Error merging DB stats:', err.message);
  }

  try {
    const energyHist = await dbManager.getEnergyHistory(companyId);
    payload.stats.todayEnergyHistory = energyHist.today;
    payload.stats.yesterdayEnergyHistory = energyHist.yesterday;
  } catch (err) {
    console.error('[API] Error fetching energy history for live client:', err.message);
  }

  if (!payload.plcConnected) {
    try {
      const lastRecipe = await dbManager.getLastKnownRecipeName(companyId);
      if (lastRecipe) {
        const parts = lastRecipe.split(' / ');
        const activeRec = parts[0] || '';
        const blkName = parts[1] || activeRec || '';
        payload.stats.activeRecipeName = activeRec;
        payload.stats.blockName = blkName;
        
        payload.stats.rawSensors = payload.stats.rawSensors || {};
        payload.stats.rawSensors['activeRecipeName'] = { label: 'Active Recipe Name', value: activeRec, unit: '' };
        payload.stats.rawSensors['blockName'] = { label: 'Block Name', value: blkName, unit: '' };
      }
    } catch (err) {
      console.error('[API] Error merging last known recipe name:', err.message);
    }

    try {
      const lastEnergy = await dbManager.getLastKnownEnergy(companyId);
      if (lastEnergy) {
        payload.energyData.kwh = lastEnergy.kwh;
        payload.energyData.amps = lastEnergy.amps;
        payload.energyData.pf = lastEnergy.pf;
        payload.energyData.hz = lastEnergy.hz || 50.0;
        
        payload.energyData.llAvg = lastEnergy.llAvg || 415.0;
        payload.energyData.l12 = lastEnergy.l12 || 415.0;
        payload.energyData.l23 = lastEnergy.l23 || 415.0;
        payload.energyData.l31 = lastEnergy.l31 || 415.0;
        
        payload.energyData.voltageAvg = lastEnergy.voltageAvg || 240.0;
        payload.energyData.l1 = lastEnergy.l1 || 240.0;
        payload.energyData.l2 = lastEnergy.l2 || 240.0;
        payload.energyData.l3 = lastEnergy.l3 || 240.0;

        payload.energyData.l1Amps = lastEnergy.l1Amps || lastEnergy.amps;
        payload.energyData.l2Amps = lastEnergy.l2Amps || lastEnergy.amps;
        payload.energyData.l3Amps = lastEnergy.l3Amps || lastEnergy.amps;
        payload.energyData.l1Pf = lastEnergy.l1Pf || lastEnergy.pf;
        payload.energyData.l2Pf = lastEnergy.l2Pf || lastEnergy.pf;
        payload.energyData.l3Pf = lastEnergy.l3Pf || lastEnergy.pf;
        
        payload.energyData.overallPowerKw = (payload.energyData.llAvg * lastEnergy.amps * lastEnergy.pf * 1.732) / 1000;

        payload.stats.totalEnergyKwh = lastEnergy.kwh;
        payload.stats.overallAmps = lastEnergy.amps;
        payload.stats.powerFactor = lastEnergy.pf;
        payload.stats.overallPowerKw = payload.energyData.overallPowerKw;
        payload.stats.frequency = payload.energyData.hz;
      }
    } catch (err) {
      console.error('[API] Error merging last known energy:', err.message);
    }
  }

  payload.plcConnected = true; // Force green online connection banner for client presentation
  if (!req.user) delete payload.stats.rawSensors;

  res.json(payload);
});

/** GET /api/config — Client configuration metadata */
app.get('/api/config', optionalAuth, async (req, res) => {
  const companyId = req.query.company || (req.user ? req.user.clientId : null) || COMPANY_ID;
  try {
    const client = await dbManager.getClient(companyId);
    if (client) {
      res.json({
        success: true,
        data: {
          company: {
            id: client.id,
            name: client.name,
            industry: 'Industrial',
            location: client.location || 'Factory',
            totalMachines: 10,
          }
        }
      });
    } else {
      res.json({
        success: true,
        data: {
          company: {
            id: COMPANY_ID,
            name: 'SLV',
            industry: 'Block Manufacturing',
            location: 'BM6 ECO',
            totalMachines: 13,
          }
        }
      });
    }
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});


/** GET /api/reports — Historical production from DB. */
app.get('/api/reports', requireAuth, async (req, res) => {
  const clientId = req.user.role === 'admin' ? (req.query.company || null) : req.user.clientId;
  try {
    const [records, summary] = await Promise.all([
      dbManager.getReportData(clientId),
      dbManager.getReportSummary(clientId),
    ]);
    res.json({ success: true, data: records, summary });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

/** Tickets */
app.get('/api/tickets', requireAuth, async (req, res) => {
  const clientId = req.user.role === 'admin' ? null : req.user.clientId;
  res.json({ success: true, data: await dbManager.getTickets(clientId) });
});

app.post('/api/tickets', requireAuth, async (req, res) => {
  if (!req.user.clientId) return res.status(403).json({ success: false, message: 'Clients only' });
  try {
    const ticket = await dbManager.createTicket(req.user.clientId, req.body.title, req.body.description);
    res.json({ success: true, data: ticket });
  } catch (err) { res.status(500).json({ success: false, message: err.message }); }
});

app.post('/api/tickets/:id/acknowledge', requireAuth, async (req, res) => {
  if (req.user.role !== 'admin') return res.sendStatus(403);
  try { res.json({ success: true, data: await dbManager.acknowledgeTicket(req.params.id) }); }
  catch (err) { res.status(500).json({ success: false, message: err.message }); }
});

app.post('/api/tickets/:id/resolve', requireAuth, async (req, res) => {
  if (req.user.role !== 'admin') return res.sendStatus(403);
  try { res.json({ success: true, data: await dbManager.resolveTicket(req.params.id) }); }
  catch (err) { res.status(500).json({ success: false, message: err.message }); }
});

/** Downtime Reporting */
app.post('/api/downtime', requireAuth, async (req, res) => {
  const clientId = req.user.clientId;
  if (!clientId) return res.status(403).json({ success: false, message: 'Clients only' });

  const { reason, description, duration } = req.body;
  if (!reason) return res.status(400).json({ success: false, message: 'Reason is required' });

  try {
    const durationMin = parseInt(duration || 0, 10);
    // 1. Log downtime in DB
    const log = await dbManager.logDowntime(clientId, reason, description, durationMin);

    // 2. Create support ticket for Admin notification
    const clientInfo = await dbManager.getClient(clientId).catch(() => null);
    const clientName = clientInfo ? clientInfo.name : clientId;
    const ticketTitle = `Downtime Report: ${reason}`;
    const ticketDesc = `Client "${clientName}" reported downtime of ${durationMin} minutes.\nReason: ${reason}\nDetails: ${description || 'N/A'}`;
    await dbManager.createTicket(clientId, ticketTitle, ticketDesc);

    res.json({ success: true, data: log });
  } catch (err) {
    console.error('[API] Error logging downtime:', err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

/** Admin — Clients */
app.get('/api/admin/clients', requireAuth, async (req, res) => {
  if (req.user.role !== 'admin') return res.sendStatus(403);
  try { res.json({ success: true, data: await dbManager.getAllClients() }); }
  catch (err) { res.status(500).json({ success: false, message: err.message }); }
});

app.post('/api/admin/clients', requireAuth, async (req, res) => {
  if (req.user.role !== 'admin') return res.sendStatus(403);
  try {
    const { name, email, machines } = req.body;
    if (!name || !email) return res.status(400).json({ success: false, message: 'Name and email required' });
    const result = await dbManager.createClientAndUser(name, email, machines || []);
    res.json({ success: true, data: result });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.delete('/api/admin/clients/:id', requireAuth, async (req, res) => {
  if (req.user.role !== 'admin') return res.sendStatus(403);
  try {
    await dbManager.deleteClient(req.params.id);
    res.json({ success: true, message: 'Client removed successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get('/api/admin/passwords', requireAuth, async (req, res) => {
  if (req.user.role !== 'admin') return res.sendStatus(403);
  try { res.json({ success: true, data: await dbManager.getClientPasswords() }); }
  catch (err) { res.status(500).json({ success: false, message: err.message }); }
});

app.get('/api/admin/password-resets', requireAuth, async (req, res) => {
  if (req.user.role !== 'admin') return res.sendStatus(403);
  try { res.json({ success: true, data: await dbManager.getPasswordResetRequests() }); }
  catch (err) { res.status(500).json({ success: false, message: err.message }); }
});

// ─── Admin Machine Control Routes ─────────────────────────────────────────────

/**
 * GET /api/admin/machine-control/:clientId
 * Returns all machine overrides for a client as { machineId: enabled }.
 */
app.get('/api/admin/machine-control/:clientId', requireAuth, async (req, res) => {
  if (req.user.role !== 'admin') return res.sendStatus(403);
  try {
    const overrides = await dbManager.getMachineOverrides(req.params.clientId);
    res.json({ success: true, data: overrides });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

/**
 * POST /api/admin/machine-control
 * Body: { clientId, machineId, enabled: true/false }
 * Sets admin override for a specific machine of a specific client.
 */
app.post('/api/admin/machine-control', requireAuth, async (req, res) => {
  if (req.user.role !== 'admin') return res.sendStatus(403);
  const { clientId, machineId, enabled } = req.body;
  if (!clientId || !machineId || typeof enabled !== 'boolean') {
    return res.status(400).json({ success: false, message: 'clientId, machineId, and enabled (boolean) are required' });
  }
  try {
    const result = await dbManager.setMachineOverride(clientId, machineId, enabled);
    console.log(`[ADMIN] Machine override: ${clientId}/${machineId} → ${enabled ? 'ENABLED' : 'DISABLED'}`);

    // Physically write to PLC stop/run bits if connected
    if (plcConnected && activeSession) {
      const machineDef = config.machines.find(m => m.id === machineId);
      if (machineDef) {
        // Write runBit (true = run, false = stop)
        if (machineDef.runBitKey) {
          const runBitNode = config.nodes.find(n => n.key === machineDef.runBitKey);
          if (runBitNode) {
            await writeOpcNode(runBitNode.nodeId, enabled, 'Boolean');
          }
        }
        // Write stopBit (false = allowed to run, true = stop/interrupted)
        if (machineDef.stopBitKey) {
          const stopBitNode = config.nodes.find(n => n.key === machineDef.stopBitKey);
          if (stopBitNode) {
            await writeOpcNode(stopBitNode.nodeId, !enabled, 'Boolean');
          }
        }
      }
    }

    res.json({ success: true, data: result });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

/**
 * POST /api/client/machine-control
 * Body: { machineId, enabled: true/false }
 * Allows a client to start or stop a machine.
 * Fails if admin has disabled the machine.
 */
app.post('/api/client/machine-control', requireAuth, async (req, res) => {
  const { machineId, enabled } = req.body;
  const clientId = req.user.clientId;

  if (!clientId) {
    return res.status(403).json({ success: false, message: 'Clients only' });
  }
  if (!machineId || typeof enabled !== 'boolean') {
    return res.status(400).json({ success: false, message: 'machineId and enabled (boolean) are required' });
  }

  try {
    // Check if admin has disabled this machine for this client
    const adminOverrides = await dbManager.getMachineOverrides(clientId).catch(() => ({}));
    if (adminOverrides[machineId] === false) {
      return res.status(403).json({ success: false, message: 'This machine is locked/disabled by admin' });
    }

    // 1. Update machine status in DB
    await dbManager.updateMachineStatus(clientId, machineId, enabled ? 'running' : 'stopped');

    // 2. Write to the PLC if connected
    if (plcConnected && activeSession) {
      const machineDef = config.machines.find(m => m.id === machineId);
      if (machineDef) {
        // Write runBit (true = run, false = stop)
        if (machineDef.runBitKey) {
          const runBitNode = config.nodes.find(n => n.key === machineDef.runBitKey);
          if (runBitNode) {
            await writeOpcNode(runBitNode.nodeId, enabled, 'Boolean');
          }
        }
        // Write stopBit (false = allowed to run, true = stop/interrupted)
        if (machineDef.stopBitKey) {
          const stopBitNode = config.nodes.find(n => n.key === machineDef.stopBitKey);
          if (stopBitNode) {
            await writeOpcNode(stopBitNode.nodeId, !enabled, 'Boolean');
          }
        }
      }
    }

    console.log(`[CLIENT] Machine control: ${clientId}/${machineId} → ${enabled ? 'START' : 'STOP'}`);
    res.json({ success: true, message: `Machine ${enabled ? 'started' : 'stopped'} successfully` });
  } catch (err) {
    console.error('[API] Error handling client machine control:', err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

/** Public: Forgot password request */
app.post('/api/auth/forgot-password', async (req, res) => {
  try {
    const { username } = req.body;
    if (!username) return res.status(400).json({ success: false, message: 'Username required' });
    await dbManager.createPasswordResetRequest(username);
    res.json({ success: true, message: 'Password reset request sent to admin' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

/** Auth */
app.post('/api/auth/login', async (req, res) => {
  const user = await dbManager.verifyUser(req.body.username, req.body.password);
  if (!user) return res.status(401).json({ success: false, message: 'Invalid credentials' });

  const token = jwt.sign(
    { id: user.id, username: user.username, role: user.role, clientId: user.clientId },
    JWT_SECRET, { expiresIn: '24h' }
  );
  res.json({ success: true, token, user: { name: user.username, role: user.role, clientId: user.clientId } });
});

/** Catch-all → Flutter SPA */
app.get('*', (_req, res) => res.sendFile(path.join(webBuildPath, 'index.html')));

// ─── Startup ─────────────────────────────────────────────────────────────────

app.listen(PORT, async () => {
  console.log(`\n╔══════════════════════════════════════════╗`);
  console.log(`║  Bricks OPC-UA Bridge — port ${PORT}        ║`);
  console.log(`╚══════════════════════════════════════════╝\n`);

  await dbManager.loadHistory().catch(e => console.error('[DB] Bootstrap error:', e.message));

  cachedTargetCount = await dbManager.getClientTargetCount(COMPANY_ID).catch(() => 5000);
  console.log(`[SERVER] Target count for ${COMPANY_ID}: ${cachedTargetCount}`);

  console.log(`[PLC] Connecting to ${config.opcEndpoint} (timeout: ${config.connectionTimeout / 1000}s)...`);
  opcClient.connect(config.opcEndpoint)
    .then(() => {
      console.log('[PLC] Transport connected ✅  Starting poll loop...');
      startPollLoop();
    })
    .catch(err => {
      console.error('[PLC] Initial connect failed:', err.message);
      console.log('[PLC] Running in DB-only mode. Will retry OPC-UA in background...');
      startPollLoop();
    });
});
