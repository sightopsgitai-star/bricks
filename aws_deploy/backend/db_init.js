'use strict';

const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST || 'database-2.c3g2ke0yoqrr.ap-south-1.rds.amazonaws.com',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'Sowkar1112',
  database: process.env.DB_NAME || 'postgres',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  ssl: {
    rejectUnauthorized: false
  }
});

async function initDb() {
  const client = await pool.connect();
  try {
    console.log('[DB] Connected to PostgreSQL. Initializing tables...');

    // ── 1. Clients Table ────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS clients (
        id             VARCHAR(50)  PRIMARY KEY,
        name           VARCHAR(100) NOT NULL,
        location       TEXT,
        contact_person TEXT,
        status         VARCHAR(20)  DEFAULT 'active',
        target_count   INTEGER      DEFAULT 5000,
        created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // ── 2. Users Table ──────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id            SERIAL       PRIMARY KEY,
        username      VARCHAR(50)  UNIQUE NOT NULL,
        password_hash TEXT         NOT NULL,
        role          VARCHAR(20)  DEFAULT 'client',
        client_id     VARCHAR(50)  REFERENCES clients(id),
        created_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // ── 3. Production History ───────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS production_history (
        id          SERIAL        PRIMARY KEY,
        client_id   VARCHAR(50)   REFERENCES clients(id),
        date        DATE          NOT NULL,
        production  INTEGER       DEFAULT 0,
        cycles      INTEGER       DEFAULT 0,
        block_count INTEGER       DEFAULT 0,
        downtime    INTEGER       DEFAULT 0,
        efficiency  DECIMAL(5,2)  DEFAULT 0.0,
        machines    INTEGER       DEFAULT 0,
        hourly_data JSONB         DEFAULT '{}',
        created_at  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (client_id, date)
      );
    `);

    // ── 4. Machine Stats (Live per-machine telemetry) ───────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS machine_stats (
        id              SERIAL        PRIMARY KEY,
        client_id       VARCHAR(50)   REFERENCES clients(id),
        machine_id      VARCHAR(50)   NOT NULL,
        status          VARCHAR(20),
        motor_current   DECIMAL(8,2),
        motor_speed_rpm DECIMAL(8,2),
        last_cycle_time DECIMAL(10,2),
        total_cycles    INTEGER,
        last_updated    TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (client_id, machine_id)
      );
    `);

    // ── 4b. Energy Telemetry (Temporary 2-Minute data) ──────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS energy_telemetry (
        id              SERIAL       PRIMARY KEY,
        client_id       VARCHAR(50)  NOT NULL,
        date            DATE         NOT NULL,
        slot            INTEGER      NOT NULL,
        energy_kwh      NUMERIC      DEFAULT 0,
        overall_amps    NUMERIC      DEFAULT 0,
        power_factor    NUMERIC      DEFAULT 0,
        created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(client_id, date, slot)
      );
    `);

    // ── 5. Support Tickets ──────────────────────────────────────────────────
    // NOTE: The canonical table is `tickets` (not `support_tickets`).
    // The old `support_tickets` table from a previous init version is superseded
    // by this definition.
    await client.query(`
      CREATE TABLE IF NOT EXISTS tickets (
        id              SERIAL      PRIMARY KEY,
        client_id       VARCHAR(50) REFERENCES clients(id),
        title           TEXT        NOT NULL,
        description     TEXT,
        status          VARCHAR(20) DEFAULT 'open',
        created_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
        acknowledged_at TIMESTAMP,
        resolved_at     TIMESTAMP
      );
    `);

    // ── 6. Machine Overrides (Admin ON/OFF control per client) ──────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS machine_overrides (
        id         SERIAL      PRIMARY KEY,
        client_id  VARCHAR(50) REFERENCES clients(id) ON DELETE CASCADE,
        machine_id VARCHAR(50) NOT NULL,
        enabled    BOOLEAN     DEFAULT TRUE,
        updated_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (client_id, machine_id)
      );
    `);

    // ── 7. Password Reset Requests ──────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS password_reset_requests (
        id         SERIAL      PRIMARY KEY,
        username   VARCHAR(50) NOT NULL,
        client_id  VARCHAR(50),
        status     VARCHAR(20) DEFAULT 'pending',
        created_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // ── 8. Downtime Logs ────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS downtime_logs (
        id          SERIAL      PRIMARY KEY,
        client_id   VARCHAR(50) REFERENCES clients(id) ON DELETE CASCADE,
        reason      VARCHAR(100) NOT NULL,
        description TEXT,
        duration    INTEGER     DEFAULT 0,
        created_at  TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // ── Migrations: safe column additions ───────────────────────────────────
    console.log('[DB] Running safe migrations...');
    const migrations = [
      `ALTER TABLE clients           ADD COLUMN IF NOT EXISTS target_count   INTEGER DEFAULT 5000`,
      `ALTER TABLE clients           ADD COLUMN IF NOT EXISTS contact_person TEXT`,
      `ALTER TABLE clients           ADD COLUMN IF NOT EXISTS email          TEXT`,
      `ALTER TABLE production_history ADD COLUMN IF NOT EXISTS client_id     VARCHAR(50)`,
      `ALTER TABLE users             ADD COLUMN IF NOT EXISTS client_id      VARCHAR(50)`,
      `ALTER TABLE users             ADD COLUMN IF NOT EXISTS plain_password  TEXT`,
      `ALTER TABLE machine_stats     ADD COLUMN IF NOT EXISTS motor_current  DECIMAL(8,2)`,
      `ALTER TABLE machine_stats     ADD COLUMN IF NOT EXISTS motor_speed_rpm DECIMAL(8,2)`,
    ];
    for (const sql of migrations) {
      try { await client.query(sql); } catch (_) {}
    }

    // ── Foreign key constraints (best-effort) ────────────────────────────────
    const fkMigrations = [
      `ALTER TABLE production_history ADD CONSTRAINT fk_ph_client  FOREIGN KEY (client_id) REFERENCES clients(id)`,
      `ALTER TABLE users              ADD CONSTRAINT fk_usr_client FOREIGN KEY (client_id) REFERENCES clients(id)`,
    ];
    for (const sql of fkMigrations) {
      try { await client.query(sql); } catch (_) {}
    }

    console.log('[DB] All tables and columns are ready! ✅');

  } catch (err) {
    console.error('[DB] Initialization error:', err.message);
  } finally {
    client.release();
    pool.end();
  }
}

initDb();
