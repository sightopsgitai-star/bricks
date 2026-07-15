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
    console.log('Checking unique constraints...');

    // Show all constraints on production_history
    const res = await client.query(`
      SELECT conname, contype, pg_get_constraintdef(oid) AS def
      FROM pg_constraint
      WHERE conrelid = 'production_history'::regclass
      ORDER BY contype;
    `);
    console.log('\nConstraints on production_history:');
    console.table(res.rows);

    // Show all constraints on users
    const res2 = await client.query(`
      SELECT conname, contype, pg_get_constraintdef(oid) AS def
      FROM pg_constraint
      WHERE conrelid = 'users'::regclass
      ORDER BY contype;
    `);
    console.log('\nConstraints on users:');
    console.table(res2.rows);

  } catch (e) {
    console.error('Error:', e.message);
  } finally {
    client.release();
    await pool.end();
  }
}

run();
