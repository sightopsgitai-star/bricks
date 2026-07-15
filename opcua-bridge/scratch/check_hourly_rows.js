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
      SELECT date::TEXT as date_str, COUNT(*) as count, MIN(hour) as min_hour, MAX(hour) as max_hour
      FROM hourly_production
      GROUP BY date::TEXT
      ORDER BY date_str DESC
    `);
    console.table(res.rows);
  } catch (e) {
    console.error(e);
  } finally {
    await pool.end();
  }
}
run();
