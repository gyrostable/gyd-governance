# Gyroscope governance repo

This is the repository for the governance system of Gyroscope.

The Gyroscope governance system is designed to bring many different stakeholder groups into governance.
Voting power is split between a number of different voting vaults, which allocate voting power to different stakeholder groups.
Furthermore, the quorum, time delay, and other parameters are set depending on the impact of the proposed changes.

### Voting power computation

The voting power of a user is computed by the `VotingPowerAggregator` contract.
This contract loops over all the vaults of the system and sums up the voting power of the user in each vault weighted with the vault's weight.
Each vote has different rules for how voting power is computed.
In most vaults, the voting power can be delegated, which decreases the voting power of the account delegating and increases the voting power of the one delegated.

The following vaults are currently implemented:

1. `FoundingFrogVault`: Every owner of a Gyro founding frog (NFT distributed on Ethereum) starts with a prescribed voting power. To claim the voting power, a user must submit a Merkle proof that it owns a founding frog by signing a message. The Merkle proof is generated from a snapshot of founding frog holders. Governance can later decide to increase the voting power of some users by calling `NFTVault.updateMultiplier`
2. `RecruitNFTVault`: This vault is similar to the `FoundingFrogVault` but the voting power is assigned when minting a `RecruitNFT`
3. `FriendlyDAOVault`: This vault allows governance to arbitrarily assign voting power to any address by calling `FriendlyDAOVault.updateDAOAndTotalWeight`. In practice, this will be used to give voting power to other DAOs that are part of the Gyroscope ecosystem.
4. `LPVault`: The `LPVault` allows a user to lock an LP token to earn voting power. There can be as many `LPVault` in existence as we decide to support LP tokens. An LP vault could be incentivised through a liquidity mining scheme implemented in its parent `LiquidityMining` contract
5. `AggregateLPVault`: This aggregates the voting power across all the registered `LPVault`s. The `LPVault`s are weighted through governance.

### Action tiering

Every function that can be called through governance is assigned a tier.
A tier contains the following information:

- `proposalThreshold`: the minimum voting power required to create a proposal
- `quorum`: the quorum to be reached for the proposal to pass
- `voteThreshold`: the minimum ratio of `for` votes for the vote to pass
- `timeLockDuration`: the length of the time lock
- `proposalLength`: the length of the proposal
- `actionLevel`: how "impactful" the given action is

Assigning a tier is done using an `ITierStrategy` implementation and varies depending on the function called.

The following strategies are implemented:

- `StaticTierStrategy`: always returns the same tier regardless of the arguments
- `SimpleThresholdStrategy`: returns a tier based on whether one of the parameters is above a given threshold
- `SetVaultFeesStrategy`: Same as `SimpleThresholdStrategy` but compares two arguments to the threshold
- `SetSystemParamsStrategy`: Similar to `SimpleThresholdStrategy` but compares a several fields of a `struct` to multiple thresholds
- `SetAddressStrategy`: Has a different tier per address argument. This is used for the `GyroConfig.setAddress` that has the power to replace parts of the system. 


### Proposal lifecycle

1. Proposal creation: A proposal, which is a list of calls to execute, is created by a participant using `GovernanceManager.createProposal`
    1. The tier (containing quorum and other metadata, see `DataTypes.Tier`) is set to the highest tier of any of the calls to execute
    2. The proposer votes are computed and checked against the proposal threshold (part of the tier information)
    3. If the proposer has enough voting power, the proposal is started
2. Voting phase
   1. Any participant with voting power is allowed to vote "for", "against", or "abstain" using `GovernanceManager.vote`
   2. A participant can change his vote at any time
3. Proposal conclusion: a vote can be concluded by anyone using `GovernanceManager.tallyVote`
   1. If the quorum is reached and the vote threshold is reached, the proposal is queued for execution
   2. If not, the proposal is marked as rejected
4. Proposal execution: a proposal can be executed by anyone using `GovernanceManager.executeProposal` once the time lock for the tallied proposal has passed


## Running the tests

The environment can be setup using the following steps

1. Create a virtual environment with `make init`
2. Activate the virtual environment with `source .venv/bin/activate`
3. Install dependencies with `make setup`

The tests can then be run using:

```
brownie test
```
