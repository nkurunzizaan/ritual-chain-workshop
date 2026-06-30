# Test Plan – StakedAIBounty

## Test Cases
1. **Happy path**: Commit with stake → reveal → judge → finalize
   - Winner gets reward + stake refunded
   - Loser loses stake to owner

2. **Cannot reveal before deadline**: Reverts with "Not reveal phase"

3. **Insufficient stake**: Reverts with "Stake too low"

4. **Only owner can judge**: Reverts with "Not challenge owner"

5. **Single participant**: Only one person submits and wins

## Run
forge test -vv
