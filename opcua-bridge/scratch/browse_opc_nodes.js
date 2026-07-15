const { OPCUAClient, AttributeIds } = require('node-opcua');

const endpointUrl = 'opc.tcp://192.168.0.1:4840';

(async () => {
  const client = OPCUAClient.create({
    applicationName: 'BrowseOpcNodes',
    connectionStrategy: { maxRetry: 1 },
    securityMode: 1,
    securityPolicy: 'None',
    endpointMustExist: false,
  });

  try {
    await client.connect(endpointUrl);
    console.log('✅ Connected to PLC');

    const session = await client.createSession();

    // Let's browse from root or some known node
    // In S7-1500, user nodes are usually under ns=4 (Objects -> ServerInterfaces -> ...)
    // Let's try to browse ObjectsFolder first
    const objectsFolder = 'ns=0;i=85';
    
    // We can also search directly for common nodes
    // Let's browse the parent of the nodes: ns=4;i=63, etc.
    // S7-1500 often has Object node like ns=4;i=1
    // Let's browse the root objects folder to find the ServerInterfaces folder
    console.log('\n--- Browsing Objects Folder ---');
    const browseResult = await session.browse(objectsFolder);
    for (const ref of browseResult.references) {
      console.log(`BrowseName: ${ref.browseName.toString().padEnd(30)} NodeId: ${ref.nodeId.toString().padEnd(20)} NodeClass: ${ref.nodeClass}`);
      if (ref.browseName.toString().includes('ServerInterfaces')) {
        // Browse ServerInterfaces
        const siResult = await session.browse(ref.nodeId);
        for (const siRef of siResult.references) {
          console.log(`  [SI] BrowseName: ${siRef.browseName.toString().padEnd(30)} NodeId: ${siRef.nodeId.toString().padEnd(20)}`);
          // Browse the children of STSTEM DATA LOGING TO AWS or similar interface
          if (siRef.browseName.toString().includes('STSTEM DATA LOGING TO AWS') || siRef.browseName.toString().includes('PLC_1') || siRef.browseName.toString().includes('Data')) {
            const childResult = await session.browse(siRef.nodeId);
            for (const childRef of childResult.references) {
              console.log(`    [Child] BrowseName: ${childRef.browseName.toString().padEnd(30)} NodeId: ${childRef.nodeId.toString().padEnd(20)}`);
            }
          }
        }
      }
    }

    await session.close();
    await client.disconnect();
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
})();
