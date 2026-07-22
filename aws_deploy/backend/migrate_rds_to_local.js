'use strict';

const { Pool } = require('pg');

const rdsPool = new Pool({
  host: 'database-2.c3g2ke0yoqrr.ap-south-1.rds.amazonaws.com',
  user: 'postgres',
  password: 'Sowkar1112',
  database: 'postgres',
  port: 5432,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 10000
});

const localPool = new Pool({
  host: '127.0.0.1',
  user: 'postgres',
  password: 'Sowkar1112',
  database: 'postgres',
  port: 5432,
  ssl: false
});

async function migrate() {
  console.log('[MIGRATE] Connecting to remote AWS RDS (database-2.c3g2ke0yoqrr...)...');
  let rdsClient, localClient;
  try {
    rdsClient = await rdsPool.connect();
    console.log('[MIGRATE] Connected to AWS RDS successfully! ✅');
  } catch (err) {
    console.error('[MIGRATE] Failed to connect to AWS RDS:', err.message);
    process.exit(1);
  }

  try {
    localClient = await localPool.connect();
    console.log('[MIGRATE] Connected to Local PostgreSQL! ✅');

    // 1. Clients
    console.log('[MIGRATE] Migrating clients table...');
    const clientsRes = await rdsClient.query('SELECT * FROM clients').catch(() => ({ rows: [] }));
    for (const row of clientsRes.rows) {
      await localClient.query(
        `INSERT INTO clients (id, name, location, contact_person, status, target_count)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (id) DO UPDATE SET
           name = EXCLUDED.name,
           location = EXCLUDED.location,
           target_count = EXCLUDED.target_count`,
        [row.id, row.name, row.location, row.contact_person, row.status, row.target_count]
      );
    }
    console.log(`[MIGRATE] Migrated ${clientsRes.rows.length} client records.`);

    // 2. Production History
    console.log('[MIGRATE] Migrating production_history table...');
    const phRes = await rdsClient.query('SELECT * FROM production_history').catch(() => ({ rows: [] }));
    let phCount = 0;
    for (const row of phRes.rows) {
      await localClient.query(
        `INSERT INTO production_history
           (client_id, date, production, cycles, block_count, downtime, efficiency, machines, hourly_data, cumulative_cycles, cumulative_blocks)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         ON CONFLICT (client_id, date) DO UPDATE SET
           production = EXCLUDED.production,
           cycles = EXCLUDED.cycles,
           block_count = EXCLUDED.block_count,
           downtime = EXCLUDED.downtime,
           efficiency = EXCLUDED.efficiency,
           machines = EXCLUDED.machines,
           hourly_data = EXCLUDED.hourly_data`,
        [
          row.client_id || 'bricks-001',
          row.date,
          row.production || 0,
          row.cycles || 0,
          row.block_count || 0,
          row.downtime || 0,
          row.efficiency || 0,
          row.machines || 0,
          row.hourly_data || {},
          row.cumulative_cycles || 0,
          row.cumulative_blocks || 0
        ]
      );
      phCount++;
    }
    console.log(`[MIGRATE] Migrated ${phCount} production history records.`);

    // 3. Hourly Production
    console.log('[MIGRATE] Migrating hourly_production table...');
    const hpRes = await rdsClient.query('SELECT * FROM hourly_production').catch(() => ({ rows: [] }));
    let hpCount = 0;
    for (const row of hpRes.rows) {
      await localClient.query(
        `INSERT INTO hourly_production
           (client_id, date, hour, production, cycles, block_count, recipe_name, min_cycle_time, max_cycle_time, energy_kwh, overall_amps, power_factor)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
         ON CONFLICT (client_id, date, hour) DO NOTHING`,
        [
          row.client_id || 'bricks-001',
          row.date,
          row.hour,
          row.production || 0,
          row.cycles || 0,
          row.block_count || 0,
          row.recipe_name,
          row.min_cycle_time || 0,
          row.max_cycle_time || 0,
          row.energy_kwh || 0,
          row.overall_amps || 0,
          row.power_factor || 0
        ]
      );
      hpCount++;
    }
    console.log(`[MIGRATE] Migrated ${hpCount} hourly production records.`);

    // 4. Energy Telemetry
    console.log('[MIGRATE] Migrating energy_telemetry table...');
    const etRes = await rdsClient.query('SELECT * FROM energy_telemetry').catch(() => ({ rows: [] }));
    let etCount = 0;
    for (const row of etRes.rows) {
      await localClient.query(
        `INSERT INTO energy_telemetry
           (client_id, date, slot, energy_kwh, overall_amps, power_factor)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (client_id, date, slot) DO NOTHING`,
        [
          row.client_id || 'bricks-001',
          row.date,
          row.slot,
          row.energy_kwh || 0,
          row.overall_amps || 0,
          row.power_factor || 0
        ]
      );
      etCount++;
    }
    console.log(`[MIGRATE] Migrated ${etCount} energy telemetry records.`);

    console.log('[MIGRATE] MIGRATION COMPLETED SUCCESSFULLY! 🎉');
  } catch (err) {
    console.error('[MIGRATE] Error during data migration:', err.message);
  } finally {
    if (rdsClient) rdsClient.release();
    if (localClient) localClient.release();
    rdsPool.end();
    localPool.end();
  }
}

migrate();
