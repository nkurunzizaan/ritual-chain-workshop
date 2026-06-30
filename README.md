# StakedAIBounty – Commit-Reveal with Staking

This contract adds a staking mechanism to the commit-reveal bounty system. Participants must stake ETH to submit, which is refunded upon reveal. Losers lose their stake to the bounty owner as a penalty.

## How it works
1. Commit phase: participants submit hashed answers with a minimum stake.
2. Reveal phase: participants reveal answers and get their stake refunded.
3. Owner triggers AI judging (off-chain).
4. Owner finalizes winner – reward goes to winner, losers' stakes are slashed.

## Why staking?
Staking discourages spam submissions and incentivizes honest participation.

## Contract Address (Ritual Testnet)
 0x96499AEE94ef646E878A09FaffbABD007F7c2931

## Network
Ritual Chain Testnet (ID: 1979)
