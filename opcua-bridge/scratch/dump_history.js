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
    const data = await pool.query(`SELECT * FROM production_history ORDER BY date DESC LIMIT 30`);
    console.table(data.rows.map(r => ({
      id: r.id,
      client_id: r.client_id,
      date: r.date instanceof Date ? r.date.toISOString().split('T')[0] : r.date,
      production: r.production,
      cycles: r.cycles,
      block_count: r.block_count,
      cumulative_cycles: r.cumulative_cycles,
      cumulative_blocks: r.cumulative_blocks,
      downtime: r.downtime,
      efficiency: r.efficiency,
      machines: r.machines
    })));
  } catch (e) { 
    console.error('Error fetching DB data:', e.message); 
  } finally { 
    await pool.end(); 
  }
}

run();
