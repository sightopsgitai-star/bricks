'use strict';

const { Pool } = require('pg');
require('dotenv').config(); // reads .env from parent directory automatically since it's in scratch/

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
  const client = await pool.connect();
  try {
    console.log('[DB] Connecting to database to optimize indexes...');
    
    // Create index on hourly_production
    console.log('[DB] Creating index on hourly_production(client_id, date)...');
    await client.query('CREATE INDEX IF NOT EXISTS idx_hourly_prod_client_date ON hourly_production(client_id, date)');
    
    // Create index on downtime_logs
    console.log('[DB] Creating index on downtime_logs(client_id)...');
    await client.query('CREATE INDEX IF NOT EXISTS idx_downtime_logs_client ON downtime_logs(client_id)');

    // Create index on machine_stats
    console.log('[DB] Creating index on machine_stats(client_id)...');
    await client.query('CREATE INDEX IF NOT EXISTS idx_machine_stats_client ON machine_stats(client_id)');

    // Create index on tickets
    console.log('[DB] Creating index on tickets(client_id)...');
    await client.query('CREATE INDEX IF NOT EXISTS idx_tickets_client ON tickets(client_id)');

    console.log('[DB] Optimization complete! All indexes created. ✅');
  } catch (err) {
    console.error('[DB] Error creating indexes:', err.message);
  } finally {
    client.release();
    pool.end();
  }
}

run();
