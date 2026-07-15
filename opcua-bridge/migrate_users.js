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
    console.log('Running migrations...');

    // 1. Add email to clients table
    await client.query(`
      ALTER TABLE clients ADD COLUMN IF NOT EXISTS email TEXT;
    `);
    console.log('✅ Added email column to clients');

    // 2. Add plain_password to users table (for admin to view)
    await client.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS plain_password TEXT;
    `);
    console.log('✅ Added plain_password column to users');

    // 3. Create password_reset_requests table (for forgot password notifications)
    await client.query(`
      CREATE TABLE IF NOT EXISTS password_reset_requests (
        id SERIAL PRIMARY KEY,
        username TEXT NOT NULL,
        client_id TEXT,
        status TEXT DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        resolved_at TIMESTAMP
      );
    `);
    console.log('✅ Created password_reset_requests table');

    console.log('\n✅ All migrations complete!');
  } catch (e) {
    console.error('Migration error:', e.message);
  } finally {
    client.release();
    await pool.end();
  }
}

run();
