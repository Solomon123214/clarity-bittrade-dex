// [Previous test content remains, adding new tests...]

Clarinet.test({
  name: "Can remove liquidity from pool",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('bittrade', 'create-pool', [
        types.uint(1),
        types.uint(1000000),
        types.uint(1000000)
      ], deployer.address),
      
      Tx.contractCall('bittrade', 'add-liquidity', [
        types.uint(1),
        types.uint(100000),
        types.uint(90000)
      ], wallet1.address),
      
      Tx.contractCall('bittrade', 'remove-liquidity', [
        types.uint(1),
        types.uint(50000),
        types.uint(45000),
        types.uint(45000),
        types.uint(30)
      ], wallet1.address)
    ]);
    
    block.receipts[2].result.expectOk();
    
    // Verify updated position
    let positionBlock = chain.mineBlock([
      Tx.contractCall('bittrade', 'get-user-position', [
        types.principal(wallet1.address),
        types.uint(1)
      ], deployer.address)
    ]);
    
    const position = positionBlock.receipts[0].result.expectSome();
    assertEquals(position.shares.toString(), types.uint(50000));
  },
});
