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
    const res = await client.query("SELECT COUNT(*) FROM energy_telemetry");
    console.log(`energy_telemetry row count: ${res.rows[0].count}`);
    
    if (res.rows[0].count > 0) {
      const res2 = await client.query("SELECT * FROM energy_telemetry ORDER BY slot ASC LIMIT 10");
      console.log(res2.rows);
    }
  } catch (err) {
    console.error(err);
  } finally {
    client.release();
    pool.end();
  }
}
run();
