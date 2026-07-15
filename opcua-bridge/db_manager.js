'use strict';

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT || 5432,
  ssl: {
    rejectUnauthorized: false
  }
});

// Prevent unhandled error exceptions on idle clients from crashing Node.js
pool.on('error', (err, client) => {
  console.error('[DB] Unexpected error on idle database client:', err.message);
});

const HISTORY_JSON_FILE = path.join(__dirname, 'history.json');
const DEFAULT_CLIENT_ID = process.env.COMPANY_ID || 'bricks-001';

// ── Type coercion helpers ────────────────────────────────────────────────────

/** Safely parse an integer; returns 0 for NaN/null/undefined. */
function toInt(val) {
  const parsed = parseInt(val, 10);
  return isNaN(parsed) ? 0 : parsed;
}

/** Safely parse a float; returns 0.0 for NaN/null/undefined. */
function toFloat(val) {
  const parsed = parseFloat(val);
  return isNaN(parsed) ? 0.0 : parsed;
}

/** Formats a date object to 'YYYY-MM-DD' local time without timezone shifts. */
function formatLocalDate(date = new Date()) {
  const d = new Date(date);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/** Formats a date object returned from a PostgreSQL DATE column (parsed in local time) to 'YYYY-MM-DD' using local getters. */
function formatDbDateOnly(date) {
  if (!date) return '';
  return formatLocalDate(date);
}

// ── Bootstrap / Migration ────────────────────────────────────────────────────

/**
 * Loads history from DB. If DB is empty, attempts to migrate from history.json.
 * Also ensures the default client, admin user, and bricks client user exist.
 */
async function loadHistory() {
  const client = await pool.connect();
  try {
    // Ensure energy_telemetry table exists
    await client.query(`
      CREATE TABLE IF NOT EXISTS energy_telemetry (
        id              SERIAL       PRIMARY KEY,
        client_id       VARCHAR(50)  NOT NULL,
        date            DATE         NOT NULL,
        slot            INTEGER      NOT NULL,
        energy_kwh      NUMERIC      DEFAULT 0,
        overall_amps    NUMERIC      DEFAULT 0,
        power_factor    NUMERIC      DEFAULT 0,
        created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(client_id, date, slot)
      );
    `);

    // Ensure downtime_logs table exists
    await client.query(`
      CREATE TABLE IF NOT EXISTS downtime_logs (
        id          SERIAL      PRIMARY KEY,
        client_id   VARCHAR(50) REFERENCES clients(id) ON DELETE CASCADE,
        reason      VARCHAR(100) NOT NULL,
        description TEXT,
        duration    INTEGER     DEFAULT 0,
        created_at  TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Ensure cumulative tracking columns exist in production_history table
    await client.query('ALTER TABLE production_history ADD COLUMN IF NOT EXISTS cumulative_cycles INTEGER DEFAULT 0');
    await client.query('ALTER TABLE production_history ADD COLUMN IF NOT EXISTS cumulative_blocks INTEGER DEFAULT 0');

    // Ensure hourly_production has recipe and min/max cycle time columns
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS recipe_name VARCHAR(100)');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS min_cycle_time NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS max_cycle_time NUMERIC DEFAULT 0');

    // Ensure hourly_production has energy metrics columns
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS energy_kwh NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS overall_amps NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS power_factor NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS voltage_avg NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS ll_avg NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS hz NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS l1 NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS l2 NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS l3 NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS l12 NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS l23 NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS l31 NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS l1_amps NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS l2_amps NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS l3_amps NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS l1_pf NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS l2_pf NUMERIC DEFAULT 0');
    await client.query('ALTER TABLE hourly_production ADD COLUMN IF NOT EXISTS l3_pf NUMERIC DEFAULT 0');

    // 1. Ensure Default Client exists
    await client.query(`
      INSERT INTO clients (id, name, location)
      VALUES ($1, $2, $3)
      ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        location = EXCLUDED.location`,
      [DEFAULT_CLIENT_ID, 'SLV', 'BM6 ECO']
    );

    // 2. Migration: history.json → production_history (if DB is empty)
    const res = await client.query('SELECT COUNT(*) FROM production_history');
    const count = parseInt(res.rows[0].count, 10);

    if (count === 0 && fs.existsSync(HISTORY_JSON_FILE)) {
      console.log(`[DB] Database is empty. Migrating data for ${DEFAULT_CLIENT_ID}...`);
      const jsonData = JSON.parse(fs.readFileSync(HISTORY_JSON_FILE, 'utf8'));

      for (const record of jsonData) {
        await client.query(
          `INSERT INTO production_history
             (client_id, date, production, cycles, block_count, downtime, efficiency, machines, hourly_data)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
           ON CONFLICT (client_id, date) DO NOTHING`,
          [
            DEFAULT_CLIENT_ID,
            record.date,
            toInt(record.production),
            toInt(record.cycles),
            toInt(record.blockCount),
            toInt(record.downtime),
            toFloat(record.efficiency),
            toInt(record.machines),
            record.hourly || {}
          ]
        );
      }
      console.log(`[DB] Migrated ${jsonData.length} records to PostgreSQL.`);
    }

    // 3. Ensure Super Admin (Armix) exists
    const adminRes = await client.query("SELECT COUNT(*) FROM users WHERE role = 'admin'");
    if (parseInt(adminRes.rows[0].count, 10) === 0) {
      const hash = await bcrypt.hash('armix2026', 10);
      await client.query(
        'INSERT INTO users (username, password_hash, role) VALUES ($1, $2, $3)',
        ['armix_admin', hash, 'admin']
      );
      console.log('[DB] Created Armix Super Admin. Username: armix_admin, Password: armix2026');
    }

    // 4. Ensure Bricks Client User exists
    const clientRes = await client.query(
      'SELECT COUNT(*) FROM users WHERE client_id = $1', [DEFAULT_CLIENT_ID]
    );
    if (parseInt(clientRes.rows[0].count, 10) === 0) {
      const hash = await bcrypt.hash('bricks123', 10);
      await client.query(
        'INSERT INTO users (username, password_hash, role, client_id) VALUES ($1, $2, $3, $4)',
        ['bricks_user', hash, 'client', DEFAULT_CLIENT_ID]
      );
      console.log('[DB] Created Bricks Client User. Username: bricks_user, Password: bricks123');
    }

    // 5. Heal historical records (copy block_count to production if production is 0)
    const fixRes = await client.query(
      'UPDATE production_history SET production = block_count WHERE (production = 0 OR production IS NULL) AND block_count > 0'
    );
    if (fixRes.rowCount > 0) {
      console.log(`[DB] Successfully healed ${fixRes.rowCount} historical daily production rows.`);
    }

    // 5b. Heal historical records where block_count itself is 0 but cycles > 0 (setting to cycles * 24)
    const healBlocksRes = await client.query(
      `UPDATE production_history 
       SET block_count = cycles * 24, production = cycles * 24 
       WHERE (block_count = 0 OR block_count IS NULL) AND cycles > 0 AND client_id = 'bricks-001'`
    );
    if (healBlocksRes.rowCount > 0) {
      console.log(`[DB] Successfully healed ${healBlocksRes.rowCount} historical rows where block_count was 0 but cycles > 0.`);
    }


  } catch (err) {
    console.error('[DB] Error during load/migration:', err.message);
  } finally {
    client.release();
  }
}

// ── Daily Production ─────────────────────────────────────────────────────────

/**
 * Upserts today's production data for a specific client.
 */
async function updateToday(stats, clientId = DEFAULT_CLIENT_ID) {
  const todayDate = formatLocalDate();
  const client = await pool.connect();
  try {
    const dailyProduction = toInt(stats.dailyProduction || stats.actualCount);
    const todayCycles = toInt(stats.todayCycles);
    const actualCount = toInt(stats.actualCount);
    const downtime = toInt(stats.totalDowntimeMinutes);
    const efficiency = toFloat(stats.overallEfficiency);
    const machineCount = toInt(stats.machinesRunning) + toInt(stats.machinesStopped);

    await client.query(
      `INSERT INTO production_history
         (client_id, date, production, cycles, block_count, downtime, efficiency, machines, hourly_data, cumulative_cycles, cumulative_blocks)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       ON CONFLICT (client_id, date) DO UPDATE SET
         production        = EXCLUDED.production,
         cycles            = EXCLUDED.cycles,
         block_count       = EXCLUDED.block_count,
         downtime          = EXCLUDED.downtime,
         efficiency        = EXCLUDED.efficiency,
         machines          = EXCLUDED.machines,
         hourly_data       = EXCLUDED.hourly_data,
         cumulative_cycles = EXCLUDED.cumulative_cycles,
         cumulative_blocks = EXCLUDED.cumulative_blocks`,
      [
        clientId, todayDate, dailyProduction, todayCycles, actualCount, downtime, efficiency, machineCount, stats.hourlyBreakdown || {},
        toInt(stats.cumulativeCycles), toInt(stats.cumulativeBlocks)
      ]
    );
  } catch (err) {
    console.error(`[DB] Failed to update today for ${clientId}:`, err.message);
  } finally {
    client.release();
  }
}

/**
 * Increments production counts for the current hour in RDS.
 * Enables the "9am-10am: 20 cycles" type reporting.
 */
async function incrementHourlyProduction(clientId, cyclesDelta, blocksDelta, recipeName, lastCycleTime) {
  if (cyclesDelta <= 0 && blocksDelta <= 0) return;
  
  const now = new Date();
  const todayDate = formatLocalDate(now);
  const currentHour = now.getHours();
  
  const client = await pool.connect();
  try {
    await client.query(
      `INSERT INTO hourly_production (client_id, date, hour, cycles, block_count, recipe_name, min_cycle_time, max_cycle_time)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (client_id, date, hour) DO UPDATE SET
         cycles = hourly_production.cycles + EXCLUDED.cycles,
         block_count = hourly_production.block_count + EXCLUDED.block_count,
         recipe_name = COALESCE(EXCLUDED.recipe_name, hourly_production.recipe_name),
         min_cycle_time = CASE 
           WHEN hourly_production.min_cycle_time IS NULL OR hourly_production.min_cycle_time = 0 THEN EXCLUDED.min_cycle_time
           WHEN EXCLUDED.min_cycle_time = 0 THEN hourly_production.min_cycle_time
           ELSE LEAST(hourly_production.min_cycle_time, EXCLUDED.min_cycle_time)
         END,
         max_cycle_time = CASE 
           WHEN hourly_production.max_cycle_time IS NULL OR hourly_production.max_cycle_time = 0 THEN EXCLUDED.max_cycle_time
           ELSE GREATEST(hourly_production.max_cycle_time, EXCLUDED.max_cycle_time)
         END`,
      [clientId, todayDate, currentHour, cyclesDelta, blocksDelta, recipeName || 'X-Shape_80MM', lastCycleTime || 0.0, lastCycleTime || 0.0]
    );
  } catch (err) {
    console.error(`[DB] Failed to increment hourly for ${clientId}:`, err.message);
  } finally {
    client.release();
  }
}

/**
 * Logs/updates live energy metrics for the current 2-minute slot in RDS.
 * Keeps today's and yesterday's 2-minute slot telemetry for the graph charts.
 * Deletes older energy telemetry automatically.
 * Also saves the cumulative hourly energy and power factor to the permanent hourly table.
 */
async function logHourlyEnergy(clientId, energyKwh, overallAmps, powerFactor, extra = {}) {
  const now = new Date();
  
  // Throttle to every 5 minutes
  const minutes = now.getMinutes();
  if (minutes % 5 !== 0) return;

  const todayDate = formatLocalDate(now);
  const currentHour = now.getHours();
  const slot = currentHour * 60 + minutes;

  const client = await pool.connect();
  try {
    // 1. Insert 2-minute slot data into the temporary energy_telemetry table for charts
    await client.query(
      `INSERT INTO energy_telemetry (client_id, date, slot, energy_kwh, overall_amps, power_factor)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (client_id, date, slot) DO UPDATE SET
         energy_kwh = EXCLUDED.energy_kwh,
         overall_amps = EXCLUDED.overall_amps,
         power_factor = EXCLUDED.power_factor`,
      [clientId, todayDate, slot, energyKwh || 0.0, overallAmps || 0.0, powerFactor || 0.0]
    );

    // 2. Insert/Update permanent hourly energy in the hourly_production table (for reporting)
    // If the hourly production record doesn't exist, we insert it with 0 cycles/blocks.
    // If it exists, we update the energy_kwh and power_factor fields.
    await client.query(
      `INSERT INTO hourly_production (client_id, date, hour, energy_kwh, power_factor)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (client_id, date, hour) DO UPDATE SET
         energy_kwh = EXCLUDED.energy_kwh,
         power_factor = EXCLUDED.power_factor`,
      [clientId, todayDate, currentHour, energyKwh || 0.0, powerFactor || 0.0]
    );

    // 3. Clean up energy telemetry older than yesterday
    await client.query(
      `DELETE FROM energy_telemetry
       WHERE date < CURRENT_DATE - INTERVAL '1 day'`
    );

  } catch (err) {
    console.error(`[DB] Failed to log 2-minute energy slot for ${clientId}:`, err.message);
  } finally {
    client.release();
  }
}


const energyHistoryCache = {};
const todayStatsCache = {};
const globalTotalCyclesCache = {};
const reportDataCache = {};
const reportSummaryCache = {};

/**
 * Fetches hourly energy metrics for today and yesterday.
 */
async function getEnergyHistory(clientId = DEFAULT_CLIENT_ID) {
  const cacheKey = clientId;
  const cached = energyHistoryCache[cacheKey];
  const nowTime = Date.now();
  if (cached && (nowTime - cached.timestamp) < 100) { // 100 milliseconds cache
    return cached.data;
  }

  const now = new Date();
  const todayDate = formatLocalDate(now);
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayDate = formatLocalDate(yesterday);

  const client = await pool.connect();
  try {
    const res = await client.query(
      `SELECT date, slot, energy_kwh, overall_amps, power_factor
       FROM energy_telemetry
       WHERE client_id = $1 AND (date = $2 OR date = $3)
       ORDER BY date ASC, slot ASC`,
      [clientId, todayDate, yesterdayDate]
    );

    const todayHistory = [];
    const yesterdayHistory = [];

    res.rows.forEach(r => {
      const d = r.date instanceof Date ? formatDbDateOnly(r.date) : r.date;
      const slot = parseInt(r.slot, 10);
      const fractionalHour = (slot / 60); // 0.0 – 23.983
      const point = {
        hour: fractionalHour,
        energy_kwh: parseFloat(r.energy_kwh || 0.0),
        overall_amps: parseFloat(r.overall_amps || 0.0),
        power_factor: parseFloat(r.power_factor || 0.0)
      };

      if (d === todayDate) {
        todayHistory.push(point);
      } else if (d === yesterdayDate) {
        yesterdayHistory.push(point);
      }
    });

    const result = {
      today: todayHistory,
      yesterday: yesterdayHistory
    };
    energyHistoryCache[cacheKey] = { data: result, timestamp: nowTime };
    return result;
  } catch (err) {
    console.error('[DB] Failed to get energy history:', err.message);
    return { today: [], yesterday: [] };
  } finally {
    client.release();
  }
}

/**
 * Fetches the single latest recorded energy telemetry from hourly_production.
 */
async function getLastKnownEnergy(clientId = DEFAULT_CLIENT_ID) {
  try {
    const res = await pool.query(
      `SELECT *
       FROM hourly_production
       WHERE client_id = $1 AND (energy_kwh > 0 OR overall_amps > 0)
       ORDER BY date DESC, hour DESC
       LIMIT 1`,
      [clientId]
    );
    if (res.rows.length > 0) {
      const r = res.rows[0];
      return {
        kwh: parseFloat(r.energy_kwh || 0.0),
        amps: parseFloat(r.overall_amps || 0.0),
        pf: parseFloat(r.power_factor || 0.0),
        voltageAvg: parseFloat(r.voltage_avg || 0.0),
        llAvg: parseFloat(r.ll_avg || 0.0),
        hz: parseFloat(r.hz || 0.0),
        l1: parseFloat(r.l1 || 0.0),
        l2: parseFloat(r.l2 || 0.0),
        l3: parseFloat(r.l3 || 0.0),
        l12: parseFloat(r.l12 || 0.0),
        l23: parseFloat(r.l23 || 0.0),
        l31: parseFloat(r.l31 || 0.0),
        l1Amps: parseFloat(r.l1_amps || 0.0),
        l2Amps: parseFloat(r.l2_amps || 0.0),
        l3Amps: parseFloat(r.l3_amps || 0.0),
        l1Pf: parseFloat(r.l1_pf || 0.0),
        l2Pf: parseFloat(r.l2_pf || 0.0),
        l3Pf: parseFloat(r.l3_pf || 0.0)
      };
    }
    return null;
  } catch (err) {
    console.error('[DB] Error fetching last known energy:', err.message);
    return null;
  }
}

/**
 * Writes live machine telemetry into the machine_stats table.
 * Uses UPSERT so each row is kept current (one row per machine per client).
 *
 * @param {Array<{id, status, motorCurrent, motorSpeedRpm, cycleCount, cureCycleTimeSec}>} machines
 * @param {string} clientId
 */
async function updateMachineStats(machines, clientId = DEFAULT_CLIENT_ID) {
  if (!machines || machines.length === 0) return;
  const client = await pool.connect();
  try {
    for (const m of machines) {
      await client.query(
        `INSERT INTO machine_stats
           (client_id, machine_id, status, motor_current, motor_speed_rpm, last_cycle_time, total_cycles, last_updated)
         VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
         ON CONFLICT (client_id, machine_id) DO UPDATE SET
           status          = EXCLUDED.status,
           motor_current   = EXCLUDED.motor_current,
           motor_speed_rpm = EXCLUDED.motor_speed_rpm,
           last_cycle_time = EXCLUDED.last_cycle_time,
           total_cycles    = EXCLUDED.total_cycles,
           last_updated    = NOW()`,
        [
          clientId,
          m.id,
          m.status || 'stopped',
          toFloat(m.motorCurrent),
          toFloat(m.motorSpeedRpm),
          toFloat(m.cureCycleTimeSec),
          toInt(m.cycleCount),
        ]
      );
    }
  } catch (err) {
    console.error('[DB] Failed to update machine stats:', err.message);
  } finally {
    client.release();
  }
}

// ── Today Stats ──────────────────────────────────────────────────────────────

/**
 * Fetches today's production stats row from RDS.
 */
async function getTodayStats(clientId = DEFAULT_CLIENT_ID) {
  const cached = todayStatsCache[clientId];
  const nowTime = Date.now();
  if (cached && (nowTime - cached.timestamp) < 100) { // 100 milliseconds cache
    return cached.data;
  }
  try {
    const todayDate = formatLocalDate();
    const res = await pool.query(
      'SELECT * FROM production_history WHERE client_id = $1 AND date = $2',
      [clientId, todayDate]
    );
    let result = null;
    if (res.rows.length > 0) {
      const r = res.rows[0];
      result = {
        production: r.production,
        cycles: r.cycles,
        blockCount: r.block_count,
        downtime: r.downtime,
        efficiency: parseFloat(r.efficiency),
        machines: r.machines,
        hourly: r.hourly_data
      };
    }
    todayStatsCache[clientId] = { data: result, timestamp: nowTime };
    return result;
  } catch (err) {
    console.error('[DB] Error fetching today stats:', err.message);
    return null;
  }
}

// ── Report Data ──────────────────────────────────────────────────────────────

/**
 * Returns all historical production rows for a given client, newest first.
 */
async function getReportData(clientId = null) {
  const cacheKey = clientId || 'all';
  const cached = reportDataCache[cacheKey];
  const nowTime = Date.now();
  if (cached && (nowTime - cached.timestamp) < 5000) { // 5 seconds cache
    return cached.data;
  }

  try {
    // 1. Fetch the daily summaries
    let summaryQuery = 'SELECT * FROM production_history';
    let params = [];
    if (clientId) {
      summaryQuery += ' WHERE client_id = $1';
      params.push(clientId);
    }
    summaryQuery += ' ORDER BY date DESC';
    const summaryRes = await pool.query(summaryQuery, params);

    // 2. Fetch hourly data for this client (limited to last 30 days for performance) to merge
    let hourlyQuery = "SELECT date, hour, cycles, block_count, recipe_name, min_cycle_time, max_cycle_time, energy_kwh, power_factor FROM hourly_production WHERE date >= CURRENT_DATE - INTERVAL '30 days'";
    let hourlyParams = [];
    if (clientId) {
      hourlyQuery += ' AND client_id = $1';
      hourlyParams.push(clientId);
    }
    const hourlyRes = await pool.query(hourlyQuery, hourlyParams);

    // Map hourly records by date for easy lookup
    const hourlyMap = {};
    hourlyRes.rows.forEach(h => {
      const d = h.date instanceof Date ? formatDbDateOnly(h.date) : h.date;
      const hr = parseInt(h.hour, 10);
      
      // We only map hours 0-23 in the hourly breakdown for reports
      if (hr <= 23) {
        if (!hourlyMap[d]) {
          hourlyMap[d] = {};
        }
        hourlyMap[d][hr] = {
          cycles: h.cycles || 0,
          blocks: h.block_count || 0,
          recipeName: h.recipe_name || 'X-Shape_80MM',
          minCycleTime: parseFloat(h.min_cycle_time || 0),
          maxCycleTime: parseFloat(h.max_cycle_time || 0),
          energyKwh: parseFloat(h.energy_kwh || 0),
          powerFactor: parseFloat(h.power_factor || 0)
        };
      }
    });

    const result = summaryRes.rows.map(r => {
      const d = r.date instanceof Date ? formatDbDateOnly(r.date) : r.date;
      
      let hourly = hourlyMap[d] || r.hourly_data || {};
      
      // Ensure we return exactly 24 keys (0 to 23)
      const hourly24 = {};
      for (let hr = 0; hr < 24; hr++) {
        const item = hourly[hr];
        hourly24[hr] = {
          cycles: item ? (item.cycles || 0) : 0,
          blocks: item ? (item.blocks || item.block_count || 0) : 0,
          recipeName: item ? (item.recipeName || item.recipe_name || 'X-Shape_80MM') : 'X-Shape_80MM',
          minCycleTime: item ? parseFloat(item.minCycleTime || item.min_cycle_time || 0) : 0,
          maxCycleTime: item ? parseFloat(item.maxCycleTime || item.max_cycle_time || 0) : 0,
          energyKwh: item ? parseFloat(item.energyKwh || item.energy_kwh || 0) : 0,
          powerFactor: item ? parseFloat(item.powerFactor || item.power_factor || 0) : 0
        };
      }



      return {
        date: d,
        production: r.production,
        cycles: r.cycles,
        blockCount: r.block_count,
        downtime: r.downtime,
        efficiency: parseFloat(r.efficiency),
        machines: r.machines,
        hourly: hourly24,
        clientId: r.client_id
      };
    });

    reportDataCache[cacheKey] = { data: result, timestamp: nowTime };
    return result;
  } catch (err) {
    console.error('[DB] Error fetching report data:', err.message);
    return [];
  }
}

/**
 * Returns aggregate summary stats across all history (or for one client).
 */
async function getReportSummary(clientId = null) {
  const cacheKey = clientId || 'all';
  const cached = reportSummaryCache[cacheKey];
  const nowTime = Date.now();
  if (cached && (nowTime - cached.timestamp) < 5000) { // 5 seconds cache
    return cached.data;
  }

  try {
    let query = `
      SELECT
        SUM(production)                            AS total_prod,
        SUM(cycles)                                AS total_cycles,
        SUM(downtime)                              AS total_downtime,
        AVG(efficiency) FILTER (WHERE efficiency > 0) AS avg_eff
      FROM production_history
    `;
    let params = [];
    if (clientId) {
      query += ' WHERE client_id = $1';
      params.push(clientId);
    }

    const res = await pool.query(query, params);
    const row = res.rows[0];
    const result = {
      totalProduction: parseInt(row.total_prod || 0, 10),
      totalCycles: parseInt(row.total_cycles || 0, 10),
      totalDowntimeMinutes: parseInt(row.total_downtime || 0, 10),
      averageEfficiency: Math.round((parseFloat(row.avg_eff) || 0) * 10) / 10
    };

    reportSummaryCache[cacheKey] = { data: result, timestamp: nowTime };
    return result;
  } catch (err) {
    console.error('[DB] Error fetching report summary:', err.message);
    return null;
  }
}

/**
 * Aggregate production sum over last N days.
 */
async function getAggregateProduction(days, clientId = null) {
  try {
    let query = 'SELECT SUM(production) AS total FROM production_history WHERE date >= CURRENT_DATE - $1::interval';
    let params = [`${days} days`];

    if (clientId) {
      query += ' AND client_id = $2';
      params.push(clientId);
    }

    const res = await pool.query(query, params);
    return parseInt(res.rows[0].total || 0, 10);
  } catch (err) {
    console.error('[DB] Error fetching aggregate production:', err.message);
    return 0;
  }
}

// ── Clients ──────────────────────────────────────────────────────────────────

/**
 * Returns all clients enriched with their most recent production date and
 * an `isOnline` flag (true if we received data within the last 15 minutes).
 */
async function getAllClients() {
  try {
    const res = await pool.query(`
      SELECT
        c.*,
        ph.production  AS last_production,
        ph.date        AS last_seen_date,
        ms.last_updated AS last_telemetry_at,
        dl.reason       AS latest_downtime_reason,
        dl.description  AS latest_downtime_description
      FROM clients c
      LEFT JOIN LATERAL (
        SELECT production, date
        FROM production_history
        WHERE client_id = c.id
        ORDER BY date DESC
        LIMIT 1
      ) ph ON true
      LEFT JOIN LATERAL (
        SELECT MAX(last_updated) AS last_updated
        FROM machine_stats
        WHERE client_id = c.id
      ) ms ON true
      LEFT JOIN LATERAL (
        SELECT reason, description
        FROM downtime_logs
        WHERE client_id = c.id
        ORDER BY created_at DESC
        LIMIT 1
      ) dl ON true
    `);

    const now = Date.now();
    return res.rows.map(r => ({
      ...r,
      // isOnline = machine_stats updated within last 15 minutes
      isOnline: r.last_telemetry_at
        ? (now - new Date(r.last_telemetry_at).getTime()) < 15 * 60 * 1000
        : false
    }));
  } catch (err) {
    console.error('[DB] Error fetching clients:', err.message);
    return [];
  }
}

/**
 * Returns a client's target_count (custom production target per client).
 * Falls back to 5000 if not found.
 */
async function getClientTargetCount(clientId = DEFAULT_CLIENT_ID) {
  try {
    const res = await pool.query(
      'SELECT target_count FROM clients WHERE id = $1',
      [clientId]
    );
    if (res.rows.length > 0) {
      return parseInt(res.rows[0].target_count || 5000, 10);
    }
    return 5000;
  } catch (err) {
    console.error('[DB] Error fetching target count:', err.message);
    return 5000;
  }
}

// ── Support Tickets ──────────────────────────────────────────────────────────

async function createTicket(clientId, title, description) {
  try {
    const res = await pool.query(
      'INSERT INTO tickets (client_id, title, description, status) VALUES ($1, $2, $3, $4) RETURNING *',
      [clientId, title, description, 'open']
    );
    return res.rows[0];
  } catch (err) {
    console.error('[DB] Error creating ticket:', err.message);
    throw err;
  }
}

async function getTickets(clientId = null) {
  try {
    let query = 'SELECT t.*, c.name AS client_name FROM tickets t JOIN clients c ON t.client_id = c.id';
    let params = [];
    if (clientId) {
      query += ' WHERE t.client_id = $1';
      params.push(clientId);
    }
    query += ' ORDER BY t.created_at DESC';
    const res = await pool.query(query, params);
    return res.rows;
  } catch (err) {
    console.error('[DB] Error fetching tickets:', err.message);
    return [];
  }
}

async function acknowledgeTicket(ticketId) {
  try {
    const res = await pool.query(
      "UPDATE tickets SET status = 'acknowledged', acknowledged_at = CURRENT_TIMESTAMP WHERE id = $1 RETURNING *",
      [ticketId]
    );
    return res.rows[0];
  } catch (err) {
    console.error('[DB] Error acknowledging ticket:', err.message);
    throw err;
  }
}

async function resolveTicket(ticketId) {
  try {
    const res = await pool.query(
      "UPDATE tickets SET status = 'resolved', resolved_at = CURRENT_TIMESTAMP WHERE id = $1 RETURNING *",
      [ticketId]
    );
    return res.rows[0];
  } catch (err) {
    console.error('[DB] Error resolving ticket:', err.message);
    throw err;
  }
}

// ── Auth ──────────────────────────────────────────────────────────────────────

/**
 * Verifies user credentials; returns user object or null on failure.
 */
async function verifyUser(username, password) {
  try {
    const res = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
    if (res.rows.length === 0) return null;

    const user = res.rows[0];
    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) return null;

    return {
      id: user.id,
      username: user.username,
      role: user.role,
      clientId: user.client_id
    };
  } catch (err) {
    console.error('[DB] Auth error:', err.message);
    return null;
  }
}

/**
 * Fetches the grand total sum of all cycles ever recorded in production_history.
 */
async function getGlobalTotalCycles(clientId = DEFAULT_CLIENT_ID) {
  const cached = globalTotalCyclesCache[clientId];
  const nowTime = Date.now();
  if (cached && (nowTime - cached.timestamp) < 100) { // 100 milliseconds cache
    return cached.data;
  }
  try {
    const res = await pool.query(
      `SELECT cumulative_cycles 
       FROM production_history 
       WHERE client_id = $1 AND cumulative_cycles > 0 
       ORDER BY date DESC 
       LIMIT 1`,
      [clientId]
    );
    let result = 0;
    if (res.rows.length > 0) {
      result = parseInt(res.rows[0].cumulative_cycles || 0, 10);
    } else {
      // Fallback if no cumulative_cycles exists
      const sumRes = await pool.query(
        'SELECT SUM(cycles) AS total FROM production_history WHERE client_id = $1',
        [clientId]
      );
      result = parseInt(sumRes.rows[0].total || 0, 10);
    }
    globalTotalCyclesCache[clientId] = { data: result, timestamp: nowTime };
    return result;
  } catch (err) {
    console.error('[DB] Error fetching global total cycles:', err.message);
    return 0;
  }
}

/**
 * Deletes a client and all their associated data.
 */
async function deleteClient(clientId) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM hourly_production WHERE client_id = $1', [clientId]);
    await client.query('DELETE FROM production_history WHERE client_id = $1', [clientId]);
    await client.query('DELETE FROM machine_stats WHERE client_id = $1', [clientId]);
    await client.query('DELETE FROM password_reset_requests WHERE client_id = $1', [clientId]);
    await client.query('DELETE FROM tickets WHERE client_id = $1', [clientId]);
    await client.query('DELETE FROM users WHERE client_id = $1', [clientId]);
    await client.query('DELETE FROM clients WHERE id = $1', [clientId]);
    await client.query('COMMIT');
    console.log(`[DB] Client ${clientId} and all data deleted.`);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[DB] Error deleting client:', err.message);
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Creates a new client and associated user account.
 * Returns the generated plain-text password and the new client id.
 */
async function createClientAndUser(name, email, machineModels) {
  const client = await pool.connect();
  try {
    // Generate alphanumeric password (8 chars)
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    let plainPassword = '';
    for (let i = 0; i < 8; i++) {
      plainPassword += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    const passwordHash = await bcrypt.hash(plainPassword, 10);

    // Generate client id from company name
    const clientId = name.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/-+/g, '-').substring(0, 20) + '-' + Date.now().toString(36);

    // Create client
    await client.query(
      `INSERT INTO clients (id, name, location, email, status) VALUES ($1, $2, $3, $4, 'active') ON CONFLICT (id) DO NOTHING`,
      [clientId, name, 'Factory', email]
    );

    // Create user — suffix with timestamp to ensure uniqueness
    const usernameSuffix = Date.now().toString(36).slice(-4);
    const username = name.toLowerCase().replace(/[^a-z0-9]/g, '_').substring(0, 12) + '_' + usernameSuffix;
    await client.query(
      `INSERT INTO users (username, password_hash, plain_password, role, client_id) VALUES ($1, $2, $3, 'client', $4)`,
      [username, passwordHash, plainPassword, clientId]
    );

    // Create dummy machine_stats rows (value 123) for each selected machine
    for (const machineModel of machineModels) {
      const machineId = machineModel.replace(/\s+/g, '-').toUpperCase() + '-001';
      await client.query(
        `INSERT INTO machine_stats (client_id, machine_id, status, motor_current, motor_speed_rpm, last_cycle_time, total_cycles, last_updated)
         VALUES ($1, $2, 'running', 12.3, 1230, 123, 123, NOW()) ON CONFLICT (client_id, machine_id) DO NOTHING`,
        [clientId, machineId]
      );
    }

    // Dummy production history
    const today = formatLocalDate();
    await client.query(
      `INSERT INTO production_history (client_id, date, production, cycles, block_count, downtime, efficiency, machines)
       VALUES ($1, $2, 123, 123, 123, 0, 85.0, $3) ON CONFLICT (client_id, date) DO NOTHING`,
      [clientId, today, machineModels.length]
    );

    return { clientId, username, plainPassword };
  } catch (err) {
    console.error('[DB] Error creating client:', err.message);
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Fetches all clients and their plain-text passwords (admin only).
 */
async function getClientPasswords() {
  try {
    const res = await pool.query(`
      SELECT u.username, u.plain_password, u.client_id, c.name AS company_name, c.email
      FROM users u
      LEFT JOIN clients c ON c.id = u.client_id
      WHERE u.role = 'client'
      ORDER BY u.id DESC
    `);
    return res.rows;
  } catch (err) {
    console.error('[DB] Error fetching passwords:', err.message);
    return [];
  }
}

/**
 * Creates a password reset request notification.
 */
async function createPasswordResetRequest(username) {
  try {
    const userRes = await pool.query('SELECT client_id FROM users WHERE username = $1', [username]);
    const clientId = userRes.rows[0]?.client_id || null;
    await pool.query(
      `INSERT INTO password_reset_requests (username, client_id, status) VALUES ($1, $2, 'pending')`,
      [username, clientId]
    );
    return { success: true };
  } catch (err) {
    console.error('[DB] Error creating password reset request:', err.message);
    throw err;
  }
}

/**
 * Fetches all pending password reset requests.
 */
async function getPasswordResetRequests() {
  try {
    const res = await pool.query(
      `SELECT pr.*, u.plain_password, c.name AS company_name 
       FROM password_reset_requests pr
       LEFT JOIN users u ON u.username = pr.username
       LEFT JOIN clients c ON c.id = pr.client_id
       ORDER BY pr.created_at DESC`
    );
    return res.rows;
  } catch (err) {
    console.error('[DB] Error fetching reset requests:', err.message);
    return [];
  }
}

/**
 * Fetches a single client by ID.
 */
async function getClient(clientId) {
  try {
    const res = await pool.query('SELECT * FROM clients WHERE id = $1', [clientId]);
    return res.rows[0] || null;
  } catch (err) {
    console.error('[DB] Error getting client:', err.message);
    return null;
  }
}

/**
 * Fetches machine stats for a client.
 */
async function getMachineStats(clientId) {
  try {
    const res = await pool.query('SELECT * FROM machine_stats WHERE client_id = $1', [clientId]);
    return res.rows;
  } catch (err) {
    console.error('[DB] Error getting machine stats:', err.message);
    return [];
  }
}

// ── Machine Overrides (Admin ON/OFF Control) ────────────────────────────────────

/**
 * Returns a map of { machineId: enabled } for all overrides of a client.
 * If a machine has no row, it is implicitly enabled (true).
 */
async function getMachineOverrides(clientId) {
  try {
    const res = await pool.query(
      'SELECT machine_id, enabled FROM machine_overrides WHERE client_id = $1',
      [clientId]
    );
    const map = {};
    res.rows.forEach(r => { map[r.machine_id] = r.enabled; });
    return map;
  } catch (err) {
    console.error('[DB] Error getting machine overrides:', err.message);
    return {};
  }
}

/**
 * Upserts an admin override for a specific machine of a specific client.
 * enabled = true  → machine is allowed to run (default)
 * enabled = false → machine is admin-locked OFF
 */
async function setMachineOverride(clientId, machineId, enabled) {
  try {
    await pool.query(
      `INSERT INTO machine_overrides (client_id, machine_id, enabled, updated_at)
       VALUES ($1, $2, $3, NOW())
       ON CONFLICT (client_id, machine_id) DO UPDATE SET
         enabled    = EXCLUDED.enabled,
         updated_at = NOW()`,
      [clientId, machineId, enabled]
    );
    return { clientId, machineId, enabled };
  } catch (err) {
    console.error('[DB] Error setting machine override:', err.message);
    throw err;
  }
}

/**
 * Updates a single machine's status in the machine_stats table.
 */
async function updateMachineStatus(clientId, machineId, status) {
  try {
    await pool.query(
      `UPDATE machine_stats 
       SET status = $1, last_updated = NOW() 
       WHERE client_id = $2 AND machine_id = $3`,
      [status, clientId, machineId]
    );
  } catch (err) {
    console.error('[DB] Error updating machine status:', err.message);
    throw err;
  }
}

/**
 * Returns cumulative cycles and blocks at the end of yesterday (or the most recent day).
 */
async function getYesterdayCumulativeValues(clientId) {
  try {
    const res = await pool.query(
      `SELECT cumulative_cycles, cumulative_blocks 
       FROM production_history 
       WHERE client_id = $1 AND date < CURRENT_DATE
       ORDER BY date DESC LIMIT 1`,
      [clientId]
    );
    if (res.rows.length > 0 && res.rows[0].cumulative_cycles > 0) {
      return {
        cycles: toInt(res.rows[0].cumulative_cycles),
        blocks: toInt(res.rows[0].cumulative_blocks)
      };
    }
  } catch (err) {
    console.error('[DB] Error getting yesterday cumulative values:', err.message);
  }
  return null;
}

/**
 * Deletes today's record (so we restart counts) and populates/heals cumulative values backwards.
 */
async function healCumulativeHistory(clientId, currentCycles, currentBlocks, todayCycles = 0, todayBlocks = 0) {
  if (!currentCycles) return;
  const client = await pool.connect();
  try {
    const todayDate = formatLocalDate();
    await client.query(
      'DELETE FROM production_history WHERE client_id = $1 AND date = $2',
      [clientId, todayDate]
    );

    const res = await client.query(
      'SELECT id, cycles, block_count FROM production_history WHERE client_id = $1 ORDER BY date DESC',
      [clientId]
    );

    let runningCycles = currentCycles - todayCycles;
    let runningBlocks = currentBlocks - todayBlocks;

    for (const row of res.rows) {
      await client.query(
        'UPDATE production_history SET cumulative_cycles = $1, cumulative_blocks = $2 WHERE id = $3',
        [runningCycles, runningBlocks, row.id]
      );
      runningCycles -= toInt(row.cycles);
      runningBlocks -= toInt(row.block_count);
    }
    console.log(`[DB] Successfully healed cumulative history for ${clientId}. Latest cumulative: cycles=${currentCycles}, blocks=${currentBlocks} (subtracted today's cycles=${todayCycles}, blocks=${todayBlocks} for history)`);
  } catch (err) {
    console.error('[DB] Error healing cumulative history:', err.message);
  } finally {
    client.release();
  }
}

/**
 * Logs a downtime event and increments the total downtime for today.
 */
async function logDowntime(clientId, reason, description, duration) {
  const client = await pool.connect();
  const todayDate = formatLocalDate();
  try {
    await client.query('BEGIN');
    
    // 1. Insert downtime log
    const res = await client.query(
      `INSERT INTO downtime_logs (client_id, reason, description, duration)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [clientId, reason, description, duration]
    );
    
    // 2. Increment today's downtime in production_history
    const checkRes = await client.query(
      'SELECT id, downtime FROM production_history WHERE client_id = $1 AND date = $2',
      [clientId, todayDate]
    );
    
    if (checkRes.rows.length > 0) {
      await client.query(
        'UPDATE production_history SET downtime = COALESCE(downtime, 0) + $1 WHERE id = $2',
        [duration, checkRes.rows[0].id]
      );
    } else {
      await client.query(
        `INSERT INTO production_history (client_id, date, downtime, production, cycles, block_count, efficiency, machines)
         VALUES ($1, $2, $3, 0, 0, 0, 0.0, 0)`,
        [clientId, todayDate, duration]
      );
    }
    
    await client.query('COMMIT');
    return res.rows[0];
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[DB] Failed to log downtime:', err.message);
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Fetches today's hourly production deltas and returns a cumulative map for the Home screen.
 */
async function getTodayHourlyBreakdown(clientId = DEFAULT_CLIENT_ID) {
  try {
    const todayDate = formatLocalDate();
    const res = await pool.query(
      `SELECT hour, cycles, block_count 
       FROM hourly_production 
       WHERE client_id = $1 AND date = $2 AND hour <= 23
       ORDER BY hour ASC`,
      [clientId, todayDate]
    );
    
    const hourlyBreakdown = {};
    let cumulativeCycles = 0;
    let cumulativeBlocks = 0;
    
    res.rows.forEach(r => {
      const hr = r.hour;
      cumulativeCycles += r.cycles || 0;
      cumulativeBlocks += r.block_count || 0;
      hourlyBreakdown[hr] = {
        cycles: cumulativeCycles,
        blocks: cumulativeBlocks
      };
    });
    
    return hourlyBreakdown;
  } catch (err) {
    console.error('[DB] Error getting today hourly breakdown:', err.message);
    return {};
  }
}

/**
 * Fetches the most recent recipe name from hourly_production for a client.
 */
async function getLastKnownRecipeName(clientId = DEFAULT_CLIENT_ID) {
  try {
    const res = await pool.query(
      `SELECT recipe_name 
       FROM hourly_production 
       WHERE client_id = $1 AND recipe_name IS NOT NULL AND recipe_name != ''
       ORDER BY date DESC, hour DESC 
       LIMIT 1`,
      [clientId]
    );
    if (res.rows.length > 0) {
      return res.rows[0].recipe_name;
    }
  } catch (err) {
    console.error('[DB] Error getting last known recipe name:', err.message);
  }
  return null;
}

// ── Exports ───────────────────────────────────────────────────────────────────

module.exports = {
  loadHistory,
  logDowntime,
  updateToday,
  incrementHourlyProduction,
  logHourlyEnergy,
  getEnergyHistory,
  updateMachineStats,
  getTodayStats,
  getGlobalTotalCycles,
  getReportData,
  getReportSummary,
  getAggregateProduction,
  getAllClients,
  getClient,
  getMachineStats,
  getClientTargetCount,
  createTicket,
  getTickets,
  acknowledgeTicket,
  resolveTicket,
  verifyUser,
  createClientAndUser,
  deleteClient,
  getClientPasswords,
  createPasswordResetRequest,
  getPasswordResetRequests,
  getMachineOverrides,
  setMachineOverride,
  updateMachineStatus,
  getYesterdayCumulativeValues,
  healCumulativeHistory,
  getLastKnownEnergy,
  getTodayHourlyBreakdown,
  getLastKnownRecipeName,
  pool
};
