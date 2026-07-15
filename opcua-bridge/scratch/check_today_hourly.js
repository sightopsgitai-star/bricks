const dbManager = require('../db_manager');
require('dotenv').config();

async function run() {
  try {
    // 1. Let's insert a couple of mock deltas for today's hours if none exist
    const client = await dbManager.pool.connect();
    try {
      const todayStr = new Date().toISOString().split('T')[0];
      // Let's insert mock production deltas for hour 9 and 10 to test
      await client.query(`
        INSERT INTO hourly_production (client_id, date, hour, cycles, block_count)
        VALUES ('bricks-001', $1, 9, 10, 240)
        ON CONFLICT (client_id, date, hour) DO UPDATE SET
          cycles = EXCLUDED.cycles,
          block_count = EXCLUDED.block_count
      `, [todayStr]);
      
      await client.query(`
        INSERT INTO hourly_production (client_id, date, hour, cycles, block_count)
        VALUES ('bricks-001', $1, 10, 15, 360)
        ON CONFLICT (client_id, date, hour) DO UPDATE SET
          cycles = EXCLUDED.cycles,
          block_count = EXCLUDED.block_count
      `, [todayStr]);
      
      console.log('Inserted today mock production deltas (Hour 9: 10 cycles, Hour 10: 15 cycles).');
    } finally {
      client.release();
    }

    // 2. Query today's hourly breakdown
    console.log('Fetching today hourly cumulative breakdown...');
    const breakdown = await dbManager.getTodayHourlyBreakdown('bricks-001');
    console.log(JSON.stringify(breakdown, null, 2));

  } catch (e) {
    console.error(e);
  } finally {
    process.exit(0);
  }
}
run();
