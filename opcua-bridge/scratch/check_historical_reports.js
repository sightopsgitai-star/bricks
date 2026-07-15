const dbManager = require('../db_manager');
require('dotenv').config();

async function run() {
  try {
    await dbManager.loadHistory();
    const reports = await dbManager.getReportData('bricks-001');
    const may25 = reports.find(r => r.date === '2026-05-25');
    if (may25) {
      console.log('--- 2026-05-25 ---');
      console.log('Production:', may25.production);
      console.log('Cycles:', may25.cycles);
      console.log('Hourly breakdown keys:', Object.keys(may25.hourly));
      console.log('Hourly data for working hours:');
      for (let hr = 9; hr <= 18; hr++) {
        console.log(`  Hour ${hr}:`, may25.hourly[hr]);
      }
      
      // Calculate total cycles sum
      let sum = 0;
      Object.keys(may25.hourly).forEach(k => {
        sum += may25.hourly[k].cycles;
      });
      console.log('Sum of hourly cycles:', sum);
    } else {
      console.log('Could not find 2026-05-25 report row!');
    }
  } catch (err) {
    console.error('Error:', err);
  } finally {
    process.exit(0);
  }
}
run();
