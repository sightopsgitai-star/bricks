'use strict';

/**
 * opc_config.js — VERIFIED node IDs from live UaExpert reading
 * PLC  : SIMATIC.S7-1500.OPC-UA.Application:PLC_1@192.168.0.1
 * Path : ServerInterfaces/STSTEM DATA LOGING TO AWS/
 *
 * NOTE: Timeouts are tuned for a ~800 ms VPN RTT (Teltonika RMS).
 */

module.exports = {
  // ── Connection ────────────────────────────────────────────────────────────
  opcEndpoint: process.env.OPC_ENDPOINT || 'opc.tcp://192.168.0.1:4840',

  // OPC-UA keepalive / session settings (raised for VPN latency)
  connectionTimeout:        60000,   // 60 s — wait for TCP connect over VPN
  requestedSessionTimeout: 120000,   // 120 s — server-side session expiry
  keepSessionAlive:         true,
  pollIntervalMs: parseInt(process.env.POLL_INTERVAL_MS || '800', 10),

  // ── Node List ─────────────────────────────────────────────────────────────
  nodes: [
    // ── Production counters ───────────────────────────────────────────────
    { key: 'systemTotalCycle',         nodeId: 'ns=4;i=63',  label: 'System Total Cycle',           unit: 'cycles', dataType: 'UInt32' },
    { key: 'systemTotalCycle2',        nodeId: 'ns=4;i=96',  label: 'System Total Cycle (alt)',      unit: 'cycles', dataType: 'UInt32' },
    { key: 'blockCount',               nodeId: 'ns=4;i=237', label: 'Block Count',                  unit: 'blocks', dataType: 'Int16'  },
    { key: 'totalBlockCountWithCycle', nodeId: 'ns=4;i=248', label: 'Total Block Count With Cycle', unit: 'blocks', dataType: 'Int16'  },
    { key: 'lastCycleTimeSec',         nodeId: 'ns=4;i=118', label: 'Last Cycle Time (sec)',         unit: 's',      dataType: 'Int16'  },
    { key: 'todayCycleCount',          nodeId: 'ns=4;i=712', label: "Today's Cycle Count",          unit: 'cycles', dataType: 'Int32'  },
    { key: 'runTimeDuration',          nodeId: 'ns=4;i=74',  label: 'Run Time Duration',            unit: 'ms',     dataType: 'TIME'   },
    { key: 'targetCycle',              nodeId: 'ns=4;i=394', label: 'Target Cycle',                 unit: 'cycles', dataType: 'Int16'  },
    { key: 'currentCycleTimeMs',       nodeId: 'ns=4;i=667', label: 'Current Cycle Time (ms)',      unit: 'ms',     dataType: 'Int32'  },
    { key: 'lastCycleTimeMs',          nodeId: 'ns=4;i=656', label: 'Last Cycle Time (ms)',         unit: 'ms',     dataType: 'Int32'  },
    { key: 'cycleTimeData',            nodeId: 'ns=4;i=678', label: 'Cycle Time Data (array)',     unit: 'ms',     dataType: 'Int32'  },

    // ── Recipe / Block info ───────────────────────────────────────────────
    { key: 'activeRecipeName',         nodeId: 'ns=4;i=595', label: 'Active Recipe Name',           unit: '',       dataType: 'String' },
    { key: 'blockName',                nodeId: 'ns=4;i=347', label: 'Block Name',                   unit: '',       dataType: 'String' },

    // ── Energy Monitoring (Power Meter) ───────────────────────────────────
    { key: 'amps',                     nodeId: 'ns=4;i=613', label: 'Overall Amps',                 unit: 'A',      dataType: 'Float'  },
    { key: 'kwh',                      nodeId: 'ns=4;i=645', label: 'Total Energy kWh (decimal)',   unit: 'kWh',    dataType: 'Float'  },
    { key: 'kwhInt',                   nodeId: 'ns=4;i=612', label: 'Total Energy kWh (integer)',   unit: 'kWh',    dataType: 'UInt16' },
    { key: 'hz',                       nodeId: 'ns=4;i=614', label: 'Frequency',                    unit: 'Hz',     dataType: 'Float'  },
    { key: 'pf',                       nodeId: 'ns=4;i=615', label: 'Power Factor',                 unit: '',       dataType: 'Float'  },
    { key: 'voltageAvg',               nodeId: 'ns=4;i=626', label: 'Voltage Avg',                  unit: 'V',      dataType: 'Float'  },
    { key: 'llAvg',                    nodeId: 'ns=4;i=634', label: 'LL Voltage Avg',               unit: 'V',      dataType: 'Float'  },
    // Phase Voltages
    { key: 'l1',                       nodeId: 'ns=4;i=606', label: 'L1 Voltage',                   unit: 'V',      dataType: 'Float'  },
    { key: 'l2',                       nodeId: 'ns=4;i=607', label: 'L2 Voltage',                   unit: 'V',      dataType: 'Float'  },
    { key: 'l3',                       nodeId: 'ns=4;i=608', label: 'L3 Voltage',                   unit: 'V',      dataType: 'Float'  },
    { key: 'l12',                      nodeId: 'ns=4;i=609', label: 'L12 Line Voltage',             unit: 'V',      dataType: 'Float'  },
    { key: 'l23',                      nodeId: 'ns=4;i=610', label: 'L23 Line Voltage',             unit: 'V',      dataType: 'Float'  },
    { key: 'l31',                      nodeId: 'ns=4;i=611', label: 'L31 Line Voltage',             unit: 'V',      dataType: 'Float'  },
    // Phase Amps
    { key: 'l1Amps',                   nodeId: 'ns=4;i=627', label: 'L1 Amps',                      unit: 'A',      dataType: 'Float'  },
    { key: 'l2Amps',                   nodeId: 'ns=4;i=628', label: 'L2 Amps',                      unit: 'A',      dataType: 'Float'  },
    { key: 'l3Amps',                   nodeId: 'ns=4;i=629', label: 'L3 Amps',                      unit: 'A',      dataType: 'Float'  },
    // Phase Power Factors
    { key: 'l1Pf',                     nodeId: 'ns=4;i=630', label: 'L1 Power Factor',              unit: '',       dataType: 'Float'  },
    { key: 'l2Pf',                     nodeId: 'ns=4;i=631', label: 'L2 Power Factor',              unit: '',       dataType: 'Float'  },
    { key: 'l3Pf',                     nodeId: 'ns=4;i=632', label: 'L3 Power Factor',              unit: '',       dataType: 'Float'  },

    // ── Motor Currents (Int16, PLC units = Amps × 10) ─────────────────────
    { key: 'vBeltMotorCurrent',               nodeId: 'ns=4;i=12',  label: 'V-Belt Motor Current',               unit: 'A', dataType: 'Int16', machineId: 'VBC-010' },
    { key: 'boardFeederMotorCurrent',         nodeId: 'ns=4;i=13',  label: 'Board Feeder Motor Current',         unit: 'A', dataType: 'Int16', machineId: 'BFC-002' },
    { key: 'mainVibratorMotorCurrent',        nodeId: 'ns=4;i=14',  label: 'Main Vibrator Motor Current',        unit: 'A', dataType: 'Int16', machineId: 'BH-001'  },
    { key: 'rackChainMotorCurrent',           nodeId: 'ns=4;i=15',  label: 'Rack Chain Motor Current',           unit: 'A', dataType: 'Int16', machineId: 'RCC-013' },
    { key: 'stackerHorizontalMotorCurrent',   nodeId: 'ns=4;i=16',  label: 'Stacker Horizontal Motor Current',   unit: 'A', dataType: 'Int16', machineId: 'SH-012'  },
    { key: 'stackerVerticalMotorCurrent',     nodeId: 'ns=4;i=17',  label: 'Stacker Vertical Motor Current',     unit: 'A', dataType: 'Int16', machineId: 'SV-011'  },
    { key: 'tamperHeadVibratorCurrent',       nodeId: 'ns=4;i=18',  label: 'Tamper Head Vibrator Motor Current', unit: 'A', dataType: 'Int16', machineId: 'TH-006'  },

    // ── Motor Speeds (RPM) ────────────────────────────────────────────────
    { key: 'boardFeederActualSpeed',          nodeId: 'ns=4;i=140', label: 'Board Feeder Actual Speed RPM',     unit: 'RPM', dataType: 'Int16',  machineId: 'BFC-002' },
    { key: 'mainVibratorActualSpeed',         nodeId: 'ns=4;i=151', label: 'Main Vibrator Actual Speed',        unit: 'RPM', dataType: 'UInt16', machineId: 'BH-001'  },
    { key: 'rackChainMotorActualSpeed',       nodeId: 'ns=4;i=162', label: 'Rack Chain Motor Actual Speed',     unit: 'RPM', dataType: 'Int16',  machineId: 'RCC-013' },
    { key: 'stackerHorizontalActualSpeed',    nodeId: 'ns=4;i=173', label: 'Stacker Horizontal Actual Speed',   unit: 'RPM', dataType: 'Int16',  machineId: 'SH-012'  },
    { key: 'stackerVerticalActualSpeed',      nodeId: 'ns=4;i=184', label: 'Stacker Vertical Actual Speed',     unit: 'RPM', dataType: 'UInt16', machineId: 'SV-011'  },
    { key: 'tamperHeadVibratorActualSpeed',   nodeId: 'ns=4;i=195', label: 'Tamper Head Vibrator Actual Speed', unit: 'RPM', dataType: 'Int16',  machineId: 'TH-006'  },
    { key: 'vBeltActualSpeed',                nodeId: 'ns=4;i=206', label: 'V-Belt Actual Speed',               unit: 'RPM', dataType: 'Int16',  machineId: 'VBC-010' },

    // ── Machine Running Bits (Boolean: TRUE = running) ────────────────────
    { key: 'runBit_BH001',    nodeId: 'ns=4;i=446', label: 'Main Vibrator Running',       unit: '', dataType: 'Boolean', machineId: 'BH-001'   },
    { key: 'runBit_BFC002',   nodeId: 'ns=4;i=450', label: 'Board Feeder Running',        unit: '', dataType: 'Boolean', machineId: 'BFC-002'  },
    { key: 'runBit_BMH003',   nodeId: 'ns=4;i=416', label: 'Base Mix Hopper Running',     unit: '', dataType: 'Boolean', machineId: 'BMH-003'  },
    { key: 'runBit_BMFB004',  nodeId: 'ns=4;i=418', label: 'Base Mix Filler Box Running', unit: '', dataType: 'Boolean', machineId: 'BMFB-004' },
    { key: 'runBit_M005',     nodeId: 'ns=4;i=421', label: 'Mould Running',               unit: '', dataType: 'Boolean', machineId: 'M-005'    },
    { key: 'runBit_TH006',    nodeId: 'ns=4;i=420', label: 'Tamper Head Running',         unit: '', dataType: 'Boolean', machineId: 'TH-006'   },
    { key: 'runBit_FMH007',   nodeId: 'ns=4;i=417', label: 'Face Mix Hopper Running',     unit: '', dataType: 'Boolean', machineId: 'FMH-007'  },
    { key: 'runBit_FMFB008',  nodeId: 'ns=4;i=419', label: 'Face Mix Filler Box Running', unit: '', dataType: 'Boolean', machineId: 'FMFB-008' },
    { key: 'runBit_FMTL009',  nodeId: 'ns=4;i=422', label: 'Face Mix Table Running',      unit: '', dataType: 'Boolean', machineId: 'FMTL-009' },
    { key: 'runBit_VBC010',   nodeId: 'ns=4;i=451', label: 'V-Belt Conveyor Running',     unit: '', dataType: 'Boolean', machineId: 'VBC-010'  },
    { key: 'runBit_SV011',    nodeId: 'ns=4;i=447', label: 'Stacker Vertical Running',    unit: '', dataType: 'Boolean', machineId: 'SV-011'   },
    { key: 'runBit_SH012',    nodeId: 'ns=4;i=448', label: 'Stacker Horizontal Running',  unit: '', dataType: 'Boolean', machineId: 'SH-012'   },
    { key: 'runBit_RCC013',   nodeId: 'ns=4;i=449', label: 'Rack Chain Running',          unit: '', dataType: 'Boolean', machineId: 'RCC-013'  },

    // ── VFD Fault Bits (Boolean: TRUE = fault active) ─────────────────────
    { key: 'vfdFault_BH001',  nodeId: 'ns=4;i=314', label: 'Main Vibrator VFD Fault',       unit: '', dataType: 'Boolean', machineId: 'BH-001'  },
    { key: 'vfdFault_BFC002', nodeId: 'ns=4;i=325', label: 'Board Feeder VFD Fault',        unit: '', dataType: 'Boolean', machineId: 'BFC-002' },
    { key: 'vfdFault_RCC013', nodeId: 'ns=4;i=303', label: 'Rack Chain VFD Fault',          unit: '', dataType: 'Boolean', machineId: 'RCC-013' },
    { key: 'vfdFault_SH012',  nodeId: 'ns=4;i=292', label: 'Stacker Horizontal VFD Fault',  unit: '', dataType: 'Boolean', machineId: 'SH-012'  },
    { key: 'vfdFault_SV011',  nodeId: 'ns=4;i=281', label: 'Stacker Vertical VFD Fault',    unit: '', dataType: 'Boolean', machineId: 'SV-011'  },
    { key: 'vfdFault_TH006',  nodeId: 'ns=4;i=270', label: 'Tamper Head VFD Fault',         unit: '', dataType: 'Boolean', machineId: 'TH-006'  },
    { key: 'vfdFault_VBC010', nodeId: 'ns=4;i=259', label: 'V-Belt VFD Fault',              unit: '', dataType: 'Boolean', machineId: 'VBC-010' },

    // ── Stop Bits (Boolean: TRUE = machine stopped by command) ────────────
    { key: 'stopBit_BH001',   nodeId: 'ns=4;i=584', label: 'Main Vibrator Stop Bit',         unit: '', dataType: 'Boolean', machineId: 'BH-001'   },
    { key: 'stopBit_BFC002',  nodeId: 'ns=4;i=474', label: 'Board Feeder Stop Bit',          unit: '', dataType: 'Boolean', machineId: 'BFC-002'  },
    { key: 'stopBit_BMFB004', nodeId: 'ns=4;i=463', label: 'Base Mix Filler Box Stop Bit',   unit: '', dataType: 'Boolean', machineId: 'BMFB-004' },
    { key: 'stopBit_M005',    nodeId: 'ns=4;i=529', label: 'Mould Stop Bit',                 unit: '', dataType: 'Boolean', machineId: 'M-005'    },
    { key: 'stopBit_TH006',   nodeId: 'ns=4;i=562', label: 'Tamper Head Stop Bit',           unit: '', dataType: 'Boolean', machineId: 'TH-006'   },
    { key: 'stopBit_FMFB008', nodeId: 'ns=4;i=518', label: 'Face Mix Filler Box Stop Bit',   unit: '', dataType: 'Boolean', machineId: 'FMFB-008' },
    { key: 'stopBit_FMTL009', nodeId: 'ns=4;i=507', label: 'Face Mix Table Stop Bit',        unit: '', dataType: 'Boolean', machineId: 'FMTL-009' },
    { key: 'stopBit_VBC010',  nodeId: 'ns=4;i=573', label: 'V-Belt Stop Bit',                unit: '', dataType: 'Boolean', machineId: 'VBC-010'  },
    { key: 'stopBit_SV011',   nodeId: 'ns=4;i=551', label: 'Stacker Vertical Stop Bit',      unit: '', dataType: 'Boolean', machineId: 'SV-011'   },
    { key: 'stopBit_SH012',   nodeId: 'ns=4;i=540', label: 'Stacker Horizontal Stop Bit',    unit: '', dataType: 'Boolean', machineId: 'SH-012'   },
    { key: 'stopBit_RCC013',  nodeId: 'ns=4;i=496', label: 'Rack Chain Stop Bit',            unit: '', dataType: 'Boolean', machineId: 'RCC-013'  },
  ],

  // ── Machine Registry (13 machines) ───────────────────────────────────────
  machines: [
    { id: 'BH-001',   name: 'Board Hopper',           type: 'Vibrator',   motorCurrentKey: 'mainVibratorMotorCurrent',      speedKey: 'mainVibratorActualSpeed',      runBitKey: 'runBit_BH001',   vfdFaultKey: 'vfdFault_BH001',  stopBitKey: 'stopBit_BH001'   },
    { id: 'BFC-002',  name: 'Board Feeder Conveyor',   type: 'Conveyor',   motorCurrentKey: 'boardFeederMotorCurrent',       speedKey: 'boardFeederActualSpeed',       runBitKey: 'runBit_BFC002',  vfdFaultKey: 'vfdFault_BFC002', stopBitKey: 'stopBit_BFC002'  },
    { id: 'BMH-003',  name: 'Base Mix Hopper',         type: 'Hopper',     motorCurrentKey: null,                            speedKey: null,                           runBitKey: 'runBit_BMH003',  vfdFaultKey: null,              stopBitKey: null              },
    { id: 'BMFB-004', name: 'Base Mix Filler Box',     type: 'Filler Box', motorCurrentKey: null,                            speedKey: null,                           runBitKey: 'runBit_BMFB004', vfdFaultKey: null,              stopBitKey: 'stopBit_BMFB004' },
    { id: 'M-005',    name: 'Mould',                   type: 'Mould',      motorCurrentKey: null,                            speedKey: null,                           runBitKey: 'runBit_M005',    vfdFaultKey: null,              stopBitKey: 'stopBit_M005'    },
    { id: 'TH-006',   name: 'Tamper Head',             type: 'Vibrator',   motorCurrentKey: 'tamperHeadVibratorCurrent',     speedKey: 'tamperHeadVibratorActualSpeed',runBitKey: 'runBit_TH006',   vfdFaultKey: 'vfdFault_TH006',  stopBitKey: 'stopBit_TH006'   },
    { id: 'FMH-007',  name: 'Face Mix Hopper',         type: 'Hopper',     motorCurrentKey: null,                            speedKey: null,                           runBitKey: 'runBit_FMH007',  vfdFaultKey: null,              stopBitKey: null              },
    { id: 'FMFB-008', name: 'Face Mix Filler Box',     type: 'Filler Box', motorCurrentKey: null,                            speedKey: null,                           runBitKey: 'runBit_FMFB008', vfdFaultKey: null,              stopBitKey: 'stopBit_FMFB008' },
    { id: 'FMTL-009', name: 'Face Mix Table Lifter',   type: 'Lifter',     motorCurrentKey: null,                            speedKey: null,                           runBitKey: 'runBit_FMTL009', vfdFaultKey: null,              stopBitKey: 'stopBit_FMTL009' },
    { id: 'VBC-010',  name: 'V-Belt Conveyor',         type: 'Conveyor',   motorCurrentKey: 'vBeltMotorCurrent',             speedKey: 'vBeltActualSpeed',             runBitKey: 'runBit_VBC010',  vfdFaultKey: 'vfdFault_VBC010', stopBitKey: 'stopBit_VBC010'  },
    { id: 'SV-011',   name: 'Stacker Vertical',        type: 'Stacker',    motorCurrentKey: 'stackerVerticalMotorCurrent',   speedKey: 'stackerVerticalActualSpeed',   runBitKey: 'runBit_SV011',   vfdFaultKey: 'vfdFault_SV011',  stopBitKey: 'stopBit_SV011'   },
    { id: 'SH-012',   name: 'Stacker Horizontal',      type: 'Stacker',    motorCurrentKey: 'stackerHorizontalMotorCurrent', speedKey: 'stackerHorizontalActualSpeed', runBitKey: 'runBit_SH012',   vfdFaultKey: 'vfdFault_SH012',  stopBitKey: 'stopBit_SH012'   },
    { id: 'RCC-013',  name: 'Rack Chain Conveyor',     type: 'Conveyor',   motorCurrentKey: 'rackChainMotorCurrent',         speedKey: 'rackChainMotorActualSpeed',    runBitKey: 'runBit_RCC013',  vfdFaultKey: 'vfdFault_RCC013', stopBitKey: 'stopBit_RCC013'  },
  ],
};
