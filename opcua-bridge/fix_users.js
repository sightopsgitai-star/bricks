'use strict';

/**
 * fix_users.js — DANGER UTILITY
 *
 * Force-resets the admin and bricks_user passwords to their defaults.
 * This MUTATES PRODUCTION data. Only run if you have locked yourself out.
 *
 * Usage:  node fix_users.js --confirm
 */

const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
require('dotenv').config();

// ── Safety guard ─────────────────────────────────────────────────────────────
if (!process.argv.includes('--confirm')) {
  console.error('');
  console.error('⚠️  WARNING: This script FORCE-RESETS production user passwords.');
  console.error('');
  console.error('   Admin password → armix2026');
  console.error('   Client password → bricks123');
  console.error('');
  console.error('   To confirm you understand the risk, run:');
  console.error('   node fix_users.js --confirm');
  console.error('');
  process.exit(1);
}

const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT || 5432,
  ssl: { rejectUnauthorized: false }
});

async function forceResetUsers() {
  const client = await pool.connect();
  try {
    console.log('[FIX] Ensuring clients exist...');
    await client.query(
      "INSERT INTO clients (id, name, location) VALUES ('bricks-001', 'SLV', 'BM6 ECO') ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, location = EXCLUDED.location"
    );

    console.log('[FIX] Force-updating user passwords...');
    const adminHash  = await bcrypt.hash('armix2026', 10);
    const bricksHash = await bcrypt.hash('bricks123', 10);

    await client.query(`
      INSERT INTO users (username, password_hash, role)
      VALUES ('armix_admin', $1, 'admin')
      ON CONFLICT (username) DO UPDATE SET password_hash = EXCLUDED.password_hash
    `, [adminHash]);

    await client.query(`
      INSERT INTO users (username, password_hash, role, client_id)
      VALUES ('bricks_user', $1, 'client', 'bricks-001')
      ON CONFLICT (username) DO UPDATE SET password_hash = EXCLUDED.password_hash
    `, [bricksHash]);

    console.log('[FIX] Passwords reset successfully! ✅');
    console.log('[FIX]   armix_admin  → armix2026');
    console.log('[FIX]   bricks_user  → bricks123');
  } catch (err) {
    console.error('[FIX] Error:', err.message);
    process.exit(1);
  } finally {
    client.release();
    pool.end();
  }
}

forceResetUsers();
