const { Pool } = require('pg');
require('dotenv').config();

console.log('Node JS Local time:', new Date().toString());
console.log('Node JS ISO String:', new Date().toISOString());
console.log('Node JS Date portion:', new Date().toISOString().split('T')[0]);

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
    const dbTime = await pool.query('SELECT NOW(), CURRENT_DATE');
    console.log('Database time:', dbTime.rows[0]);
  } catch (e) {
    console.error(e);
  } finally {
    await pool.end();
  }
}
run();
