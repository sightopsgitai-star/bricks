const http = require('http');
const fs = require('fs');
const path = require('path');

const token = require('jsonwebtoken').sign(
  { id: 1, username: 'bricks_user', role: 'client', clientId: 'bricks-001' },
  'bricks_secret_key_123'
);

const options = {
  hostname: 'localhost',
  port: 3001,
  path: '/api/data',
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${token}`
  }
};

http.get(options, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      console.log('PLC connected:', parsed.plcConnected);
      console.log('Stats:', parsed.stats);
      fs.writeFileSync(path.join(__dirname, 'api_data_response.json'), JSON.stringify(parsed, null, 2));
      console.log('Saved full response to api_data_response.json');
    } catch (e) {
      console.error('Parse error:', e.message);
      console.log('Raw data received length:', data.length);
    }
  });
}).on('error', (err) => {
  console.error('Fetch error:', err.message);
});
