const dbManager = require('../db_manager');
require('dotenv').config();

async function run() {
  try {
    console.log('[TEST] Initializing database connections & running migrations...');
    await dbManager.loadHistory();
    console.log('[TEST] Migrations complete. Fetching report data...');
    const reports = await dbManager.getReportData('bricks-001');
    console.log(`[TEST] Successfully retrieved ${reports.length} report rows.`);
    
    // Find a row with cycles > 0
    const activeRow = reports.find(r => r.cycles > 0);
    if (activeRow) {
      console.log(`[TEST] Found active report row for date: ${activeRow.date}`);
      console.log('Production:', activeRow.production);
      console.log('Cycles:', activeRow.cycles);
      console.log('Hourly breakdown keys:', Object.keys(activeRow.hourly));
      console.log('Hourly breakdown content sample:');
      const hourlyKeys = Object.keys(activeRow.hourly).sort((a, b) => parseInt(a) - parseInt(b));
      hourlyKeys.forEach(k => {
        console.log(`  Hour ${k}:`, activeRow.hourly[k]);
      });
    } else {
      console.log('[TEST] No active rows (cycles > 0) found in reports.');
    }
  } catch (err) {
    console.error('[TEST] Error running reports logic test:', err);
  } finally {
    process.exit(0);
  }
}

run();
