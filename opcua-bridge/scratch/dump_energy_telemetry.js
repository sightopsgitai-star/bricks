'use strict';

const { Pool } = require('pg');
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

async function run() {
  const client = pool; // use pool directly
  try {
    console.log('[DB] Checking energy_telemetry rows...');
    const res = await client.query(`
      SELECT date, COUNT(*), MIN(slot), MAX(slot)
      FROM energy_telemetry
      GROUP BY date
      ORDER BY date DESC
    `);
    console.log('Daily energy_telemetry counts:');
    console.log(res.rows);

    const detailRes = await client.query(`
      SELECT date, slot, energy_kwh, overall_amps, power_factor
      FROM energy_telemetry
      ORDER BY date DESC, slot ASC
      LIMIT 100
    `);
    console.log('\nFirst 100 rows of detail:');
    console.log(detailRes.rows.map(r => ({
      date: r.date.toISOString().split('T')[0],
      slot: r.slot,
      time: `${Math.floor(r.slot / 60)}:${r.slot % 60}`,
      kwh: r.energy_kwh,
      amps: r.overall_amps,
      pf: r.power_factor
    })));

  } catch (err) {
    console.error('[DB] Error checking energy telemetry:', err.message);
  } finally {
    pool.end();
  }
}

run();
