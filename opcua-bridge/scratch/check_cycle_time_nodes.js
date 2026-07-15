const { OPCUAClient, AttributeIds } = require('node-opcua');

const endpointUrl = 'opc.tcp://192.168.0.1:4840';

(async () => {
  const client = OPCUAClient.create({
    applicationName: 'CheckCycleTimeNodes',
    connectionStrategy: { maxRetry: 1 },
    securityMode: 1,
    securityPolicy: 'None',
    endpointMustExist: false,
  });

  try {
    await client.connect(endpointUrl);
    console.log('✅ Connected to PLC');

    const session = await client.createSession();

    const nodesToRead = [
      { key: 'lastCycleTimeSec',         nodeId: 'ns=4;i=118' },
      { key: 'lastCycleTimeMs',          nodeId: 'ns=4;i=656' },
      { key: 'currentCycleTimeMs',       nodeId: 'ns=4;i=667' },
      { key: 'cycleTimeData',            nodeId: 'ns=4;i=678' },
    ];

    const results = await session.read(nodesToRead.map(n => ({ nodeId: n.nodeId, attributeId: AttributeIds.Value })));

    console.log('\n--- Cycle Time Nodes ---');
    nodesToRead.forEach((node, idx) => {
      const dv = results[idx];
      console.log(`${node.key.padEnd(25)} (${node.nodeId.padEnd(11)}): value = ${dv.value?.value}  type = ${dv.value?.dataType}`);
    });

    await session.close();
    await client.disconnect();
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
})();
