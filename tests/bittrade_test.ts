import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create new pool - owner only",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      // Owner creating pool should succeed
      Tx.contractCall('bittrade', 'create-pool', [
        types.uint(1),
        types.uint(1000000),
        types.uint(1000000)
      ], deployer.address),
      
      // Non-owner creating pool should fail
      Tx.contractCall('bittrade', 'create-pool', [
        types.uint(2),
        types.uint(1000000),
        types.uint(1000000)
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectOk();
    block.receipts[1].result.expectErr(types.uint(100)); // err-owner-only
  },
});

Clarinet.test({
  name: "Can add liquidity to existing pool",
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
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectOk();
    block.receipts[1].result.expectOk();
    
    // Verify position
    let positionBlock = chain.mineBlock([
      Tx.contractCall('bittrade', 'get-user-position', [
        types.principal(wallet1.address),
        types.uint(1)
      ], deployer.address)
    ]);
    
    const position = positionBlock.receipts[0].result.expectSome();
    assertEquals(position.shares.toString(), types.uint(100000));
  },
});

Clarinet.test({
  name: "Can perform multi-asset swaps",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Create multiple pools
    let setupBlock = chain.mineBlock([
      Tx.contractCall('bittrade', 'create-pool', [
        types.uint(1),
        types.uint(1000000),
        types.uint(1000000)
      ], deployer.address),
      Tx.contractCall('bittrade', 'create-pool', [
        types.uint(2),
        types.uint(1000000),
        types.uint(1000000)
      ], deployer.address)
    ]);
    
    setupBlock.receipts.map(receipt => receipt.result.expectOk());
    
    // Perform multi-asset swap
    let swapBlock = chain.mineBlock([
      Tx.contractCall('bittrade', 'multi-asset-swap', [
        types.list([types.uint(1), types.uint(2)]),
        types.uint(100000),
        types.uint(90000)
      ], wallet1.address)
    ]);
    
    const swapResult = swapBlock.receipts[0].result.expectOk();
    assertEquals(swapResult.toString() > types.uint(90000), true);
  },
});
