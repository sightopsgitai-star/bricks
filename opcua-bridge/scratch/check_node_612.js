/**
 * Checks the live value of ns=4;i=612 from the OPC-UA server
 * to determine if it's the integer kWh part.
 */
const { OPCUAClient, AttributeIds } = require('node-opcua');

const endpointUrl = 'opc.tcp://192.168.0.1:4840';
const nodeId = 'ns=4;i=612';

(async () => {
  const client = OPCUAClient.create({
    applicationName: 'CheckNode612',
    connectionStrategy: { maxRetry: 1 },
    securityMode: 1,
    securityPolicy: 'None',
    endpointMustExist: false,
  });

  try {
    await client.connect(endpointUrl);
    console.log('✅ Connected to PLC');

    const session = await client.createSession();

    // Also read ns=4;i=645 (kWh-decimal) for comparison
    const nodesToRead = [
      { nodeId: 'ns=4;i=612', attributeId: AttributeIds.Value },
      { nodeId: 'ns=4;i=645', attributeId: AttributeIds.Value },
    ];

    const results = await session.read(nodesToRead);

    console.log('\n--- Node Values ---');
    console.log(`ns=4;i=612  value: ${results[0].value.value}  type: ${results[0].value.dataType}`);
    console.log(`ns=4;i=645  value: ${results[1].value.value}  type: ${results[1].value.dataType}`);

    const intPart   = results[0].value.value;
    const decPart   = results[1].value.value;
    if (typeof intPart === 'number' && typeof decPart === 'number') {
      const fullKwh = intPart + decPart;
      console.log(`\n🔋 Combined kWh = ${intPart} + ${decPart.toFixed(2)} = ${fullKwh.toFixed(2)} kWh`);
    }

    await session.close();
    await client.disconnect();
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
})();
