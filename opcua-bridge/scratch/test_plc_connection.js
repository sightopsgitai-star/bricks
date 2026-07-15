'use strict';

const net = require('net');
require('dotenv').config();

// Parse PLC IP and Port from OPC_ENDPOINT
const endpoint = process.env.OPC_ENDPOINT || 'opc.tcp://192.168.0.1:4840';
console.log(`Configured OPC-UA Endpoint: ${endpoint}`);

let host = '192.168.0.1';
let port = 4840;

const match = endpoint.match(/opc\.tcp:\/\/([^:]+)(?::(\d+))?/);
if (match) {
  host = match[1];
  if (match[2]) {
    port = parseInt(match[2], 10);
  }
}

console.log(`Extracted Host: ${host}`);
console.log(`Extracted Port: ${port}`);
console.log('----------------------------------------------------');
console.log(`Testing TCP connection to ${host}:${port}...`);

const socket = new net.Socket();
const start = Date.now();

socket.setTimeout(5000);

socket.on('connect', () => {
  const duration = Date.now() - start;
  console.log(`\x1b[32m[SUCCESS]\x1b[0m Connected to PLC successfully in ${duration}ms!`);
  console.log('This means your laptop has direct network access to the PLC.');
  console.log('You do NOT need OpenVPN running on this laptop.');
  socket.destroy();
  process.exit(0);
});

socket.on('timeout', () => {
  console.log(`\x1b[31m[TIMEOUT]\x1b[0m Connection timed out after 5000ms.`);
  console.log('Could not connect to the PLC.');
  console.log('Suggestions:');
  console.log('1. Make sure you are physically connected to the factory network (Wi-Fi or Ethernet cable).');
  console.log('2. Check if your laptop IP is in the same subnet (e.g. 192.168.0.x).');
  console.log('3. If you are remote (not at the factory), you MUST connect to the factory VPN using a client profile (like selvarithik1167@gmail.com).');
  socket.destroy();
  process.exit(1);
});

socket.on('error', (err) => {
  console.log(`\x1b[31m[ERROR]\x1b[0m Connection failed: ${err.message}`);
  console.log('Suggestions:');
  console.log('1. Verify that the PLC is powered on and running.');
  console.log('2. Double check if the PLC IP address has changed.');
  console.log('3. Verify router port forwarding if accessing remotely.');
  socket.destroy();
  process.exit(1);
});

socket.connect(port, host);
