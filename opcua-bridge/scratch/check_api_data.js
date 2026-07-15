const http = require('http');

http.get('http://localhost:3001/api/data', (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      console.log('Success:', parsed.success);
      console.log('PLC Connected:', parsed.plcConnected);
      console.log('totalCycles:', parsed.stats.totalCycles);
      console.log('actualCount:', parsed.stats.actualCount);
      console.log('energyData:', parsed.energyData);
      console.log('stats energy fields:', {
        overallPowerKw: parsed.stats.overallPowerKw,
        totalEnergyKwh: parsed.stats.totalEnergyKwh,
        overallAmps: parsed.stats.overallAmps,
        powerFactor: parsed.stats.powerFactor,
        frequency: parsed.stats.frequency
      });
    } catch (e) {
      console.error('Failed to parse JSON:', e.message);
    }
  });
}).on('error', (err) => {
  console.error('Error fetching API:', err.message);
});
