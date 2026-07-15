const http = require('http');

const token = require('jsonwebtoken').sign(
  { id: 1, username: 'bricks_user', role: 'client', clientId: 'bricks-001' },
  'bricks_secret_key_123'
);

const options = {
  hostname: 'localhost',
  port: 3001,
  path: '/api/reports',
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
      console.log('Success:', parsed.success);
      console.log('Report Data (first 5 rows):');
      console.table(parsed.data.slice(0, 5));
      console.log('Summary:', parsed.summary);
    } catch (e) {
      console.error('Parse error:', e.message);
    }
  });
}).on('error', (err) => {
  console.error('Fetch error:', err.message);
});
