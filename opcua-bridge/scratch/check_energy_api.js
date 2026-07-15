const http = require('http');

http.get('http://localhost:3001/api/data', (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      console.log('Success:', parsed.success);
      console.log('PLC Connected:', parsed.plcConnected);
      console.log('Energy Data keys:', Object.keys(parsed.energyData || {}));
      console.log('Today Energy History:', parsed.stats.todayEnergyHistory);
      console.log('Yesterday Energy History:', parsed.stats.yesterdayEnergyHistory);
    } catch (e) {
      console.error('Failed to parse JSON:', e.message);
    }
  });
}).on('error', (err) => {
  console.error('Error fetching API:', err.message);
});
