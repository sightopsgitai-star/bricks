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
      SELECT date::TEXT as date_str, COUNT(*) as cnt, MIN(hour) as min_slot, MAX(hour) as max_slot
      FROM hourly_production 
      GROUP BY date
      ORDER BY date ASC
    `);
    console.log('Hourly production stats per day:');
    console.table(res.rows);
  } catch (e) {
    console.error(e);
  } finally {
    await pool.end();
  }
}
run();
