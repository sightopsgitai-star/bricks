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
    const res = await client.query(`
      SELECT u.username, u.plain_password, u.client_id, c.name AS company_name
      FROM users u
      LEFT JOIN clients c ON c.id = u.client_id
    `);
    console.log('Registered Users:');
    console.table(res.rows);
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

run();
