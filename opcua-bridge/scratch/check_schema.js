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
    const columns = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'hourly_production'
    `);
    console.log('Columns in hourly_production:');
    console.table(columns.rows);

    const firstRow = await pool.query(`SELECT * FROM production_history LIMIT 1`);
    console.log('First raw row structure:');
    console.log(firstRow.rows[0]);
  } catch (e) { 
    console.error('Error:', e.message); 
  } finally { 
    await pool.end(); 
  }
}

run();
