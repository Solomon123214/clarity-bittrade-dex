# BitTrade DEX

A decentralized exchange (DEX) for trading synthetic assets built on the Stacks blockchain using Clarity smart contracts.

## Features
- Create and trade synthetic assets
- Provide liquidity to asset pools
- Automated market maker functionality
- Permissionless trading
- Decentralized price oracle integration
- Multi-asset swaps with optimal routing
- Efficient path finding for complex trades

## Getting Started
1. Install Clarinet
2. Clone this repository
3. Run tests with `clarinet test`
4. Deploy contract using Clarinet console

## Usage
The contract provides functionality to:
- Create synthetic assets
- Add/remove liquidity
- Trade assets directly or via multi-hop swaps
- View asset prices and pool info
- Find optimal trading paths

### Multi-Asset Swaps
The new multi-asset swap feature allows traders to:
- Execute trades across multiple pools in a single transaction
- Automatically find the most efficient trading path
- Reduce slippage and improve execution prices
- Support up to 5 hops per trade
