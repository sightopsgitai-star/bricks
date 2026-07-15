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
    // Create the hourly_production table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS hourly_production (
        id SERIAL PRIMARY KEY,
        client_id TEXT NOT NULL,
        date DATE NOT NULL,
        hour INTEGER NOT NULL,
        cycles INTEGER DEFAULT 0,
        block_count INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(client_id, date, hour)
      );
    `);
    console.log('Table hourly_production created ✅');
    
    // Also ensure production_history has the hourly_data column (as backup/summary)
    await pool.query(`
      ALTER TABLE production_history ADD COLUMN IF NOT EXISTS hourly_data JSONB DEFAULT '{}';
    `);
    console.log('Column hourly_data verified in production_history ✅');

  } catch (e) { 
    console.error('Migration Error:', e.message); 
  } finally { 
    await pool.end(); 
  }
}

run();
