const { OPCUAClient, AttributeIds } = require('node-opcua');

const endpointUrl = 'opc.tcp://192.168.0.1:4840';

(async () => {
  const client = OPCUAClient.create({
    applicationName: 'CheckProductionCounters',
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
      { key: 'systemTotalCycle',         nodeId: 'ns=4;i=63' },
      { key: 'systemTotalCycle2',        nodeId: 'ns=4;i=96' },
      { key: 'blockCount',               nodeId: 'ns=4;i=237' },
      { key: 'totalBlockCountWithCycle', nodeId: 'ns=4;i=248' },
      { key: 'lastCycleTimeSec',         nodeId: 'ns=4;i=118' },
      { key: 'todayCycleCount',          nodeId: 'ns=4;i=712' },
      { key: 'runTimeDuration',          nodeId: 'ns=4;i=74' },
      { key: 'targetCycle',              nodeId: 'ns=4;i=394' },
      { key: 'currentCycleTimeMs',       nodeId: 'ns=4;i=667' },
      { key: 'lastCycleTimeMs',          nodeId: 'ns=4;i=665' },
      { key: 'activeRecipeName',         nodeId: 'ns=4;i=595' },
      { key: 'blockName',                nodeId: 'ns=4;i=347' },
    ];

    const results = await session.read(nodesToRead.map(n => ({ nodeId: n.nodeId, attributeId: AttributeIds.Value })));

    console.log('\n--- Production Counter Values ---');
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
