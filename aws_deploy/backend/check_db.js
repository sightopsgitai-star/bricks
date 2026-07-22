'use strict';

const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST || '127.0.0.1',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'Sowkar1112',
  database: process.env.DB_NAME || 'postgres',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  ssl: process.env.DB_HOST ? { rejectUnauthorized: false } : false
});

async function run() {
  const client = await pool.connect();
  try {
    console.log('[DB] Checking table row counts...');
    const tables = ['users', 'clients', 'production_history', 'hourly_production', 'downtime_logs', 'machine_stats', 'tickets'];
    for (const table of tables) {
      const res = await client.query(`SELECT COUNT(*) FROM ${table}`);
      console.log(`Table '${table}': ${res.rows[0].count} rows`);
    }
  } catch (err) {
    console.error('[DB] Error checking DB:', err.message);
  } finally {
    client.release();
    pool.end();
  }
}

run();
