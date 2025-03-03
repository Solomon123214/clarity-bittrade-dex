// [Previous test content with additional tests]

Clarinet.test({
  name: "Ensures reentrancy protection works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('bittrade', 'create-pool', [
        types.uint(1),
        types.uint(1000000),
        types.uint(1000000)
      ], deployer.address),
      
      // Attempt reentrancy
      Tx.contractCall('bittrade', 'remove-liquidity', [
        types.uint(1),
        types.uint(50000),
        types.uint(45000),
        types.uint(45000),
        types.uint(30)
      ], wallet1.address)
    ]);
    
    block.receipts[1].result.expectErr(109); // err-reentrancy
  },
});

Clarinet.test({
  name: "Emergency withdrawal works when paused",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('bittrade', 'set-paused', [
        types.bool(true)
      ], deployer.address),
      
      Tx.contractCall('bittrade', 'emergency-withdraw', [
        types.uint(1)
      ], deployer.address)
    ]);
    
    block.receipts[1].result.expectOk();
  },
});
