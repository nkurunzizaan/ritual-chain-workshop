# Test Plan – StakedAIBounty

- Happy path: commit with stake → reveal → judge → finalize
- Cannot reveal before deadline (reverts)
- Insufficient stake (reverts)
- Only owner can judge (reverts)
