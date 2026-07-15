const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({ 
  host: process.env.DB_HOST, 
  user: process.env.DB_USER, 
  password: process.env.DB_PASSWORD, 
  database: process.env.DB_NAME, 
  port: process.env.DB_PORT || 5432, 
  ssl: { rejectUnauthorized: false } 
});

async function run() {
  const client = await pool.connect();
  try {
    console.log('Fixing constraints...');

    // Drop the bad single-column unique constraint on date
    await client.query(`
      ALTER TABLE production_history DROP CONSTRAINT IF EXISTS production_history_date_key;
    `);
    console.log('✅ Dropped production_history_date_key constraint');

  } catch (e) {
    console.error('Error:', e.message);
  } finally {
    client.release();
    await pool.end();
  }
}

run();
