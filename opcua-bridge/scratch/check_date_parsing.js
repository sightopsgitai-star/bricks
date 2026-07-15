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
      SELECT date
      FROM production_history 
      ORDER BY date DESC LIMIT 1
    `);
    const row = res.rows[0];
    if (row) {
      const d = row.date;
      console.log('Type of date:', typeof d);
      console.log('Is Date instance:', d instanceof Date);
      console.log('toString:', d.toString());
      console.log('toISOString:', d.toISOString());
      console.log('getUTCHours:', d.getUTCHours());
      console.log('getHours:', d.getHours());
      console.log('getFullYear / month / date (local):', d.getFullYear(), d.getMonth() + 1, d.getDate());
      console.log('getUTCFullYear / month / date (UTC):', d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate());
    } else {
      console.log('No rows found');
    }
  } catch (e) {
    console.error(e);
  } finally {
    await pool.end();
  }
}
run();
