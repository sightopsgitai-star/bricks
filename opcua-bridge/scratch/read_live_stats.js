const { OPCUAClient, AttributeIds } = require('node-opcua');

const endpointUrl = 'opc.tcp://192.168.0.1:4840';

(async () => {
  const client = OPCUAClient.create({
    applicationName: 'ReadLiveStats',
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
      { key: 'systemTotalCycle', nodeId: 'ns=4;i=63' },
      { key: 'lastCycleTimeSec', nodeId: 'ns=4;i=118' },
      { key: 'todayCycleCount', nodeId: 'ns=4;i=85' },
      { key: 'runTimeDuration', nodeId: 'ns=4;i=74' },
      { key: 'blockCount', nodeId: 'ns=4;i=237' },
      { key: 'totalBlockCountWithCycle', nodeId: 'ns=4;i=248' },
      { key: 'activeRecipeName', nodeId: 'ns=4;i=595' },
      { key: 'blockName', nodeId: 'ns=4;i=347' }
    ];

    const results = await session.read(nodesToRead.map(n => ({ nodeId: n.nodeId, attributeId: AttributeIds.Value })));

    console.log('\n--- Node Values ---');
    nodesToRead.forEach((node, i) => {
      const dataValue = results[i];
      if (dataValue && dataValue.value) {
        console.log(`${node.key} (${node.nodeId}): value = ${dataValue.value.value}  type = ${dataValue.value.dataType}`);
      } else {
        console.log(`${node.key} (${node.nodeId}): FAILED TO READ`);
      }
    });

    await session.close();
    await client.disconnect();
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
})();
