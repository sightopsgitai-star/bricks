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
  try {
    const res = await pool.query(`
      SELECT id, date::TEXT as date_str, production, cycles, block_count, cumulative_cycles, cumulative_blocks 
      FROM production_history 
      ORDER BY date DESC LIMIT 10
    `);
    console.table(res.rows);
  } catch (e) {
    console.error(e);
  } finally {
    await pool.end();
  }
}
run();
