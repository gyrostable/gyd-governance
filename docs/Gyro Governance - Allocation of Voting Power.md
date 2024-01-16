# Gyro Governance - Allocation of Voting Power
The following explain how an address/person/user receives voting power (or just "power" going forward) and how to track this data on, e.g., Dune.

Voting power arises in in two steps:
1. Within each vault, the power of that vault is allocated to addresses.
2. Across vaults, the final voting power of an address arises from summing up and weighting its power arising from each individual vault.

Note that in principle, any given address can receive voting power from multiple vaults. In practice, this will be rare (i.e., each address will usually have positive voting power in at most one vault). But here we discuss the general case, which will won't be harder to compute either.

Note that the claiming of voting power mostly doesn't raise events in the governance system, so you'll have to look at calls to the respective functions (see below). Delegation (see below) and voting *does* raise events.

## Within Each Vault
Let's focus on a single voting vault first.

Each vault has a unit called **raw voting power**. The vault stores its **total raw voting power** and each address has some individual raw power.

Raw power is only meaningful within a given vault; the values for raw power are not comparable across vaults. For example, address A may have a raw power of 10 in the founding frogger vault, and address B may have a raw power of 10 million in the LP vault, but this does mean that B has "1 million times as much" raw power than A because these are different vaults.

A user's **(not raw) voting power arising from the vault** is then the quotient

$$
\frac {\text{the user's raw power}} {\text{total raw power}}
$$

For *some* vaults we have that `total raw power = SUM(individual raw powers across the vault)`, but this is not the case for all vaults: some raw power can be left unallocated. This is done to prevent a situation where someone can claim the power of a whole vault simply by being the only person in it (or a small number of people would do this).

You can query a vault's total raw power on-chain using `.getTotalRawVotingPower()` and an address's raw power using `.getRawVotingPower()`.

We now go through the individual vaults one-by-one and explain the dynamics of their raw voting power.

### Founding Member Vault
We have a table of addresses (founding members) and each address has number called "multiplier" associated. Multipliers arise from the actions that the user has taken during the Gyro testnet phase (anti-Sybil challenges).

- Total raw voting power = SUM(multipliers) *in the table*. Note that this is a fixed number (namely 24,268).
- Individual raw voting power = a user's multiplier.

Users have to claim their raw power. A user who is in the list can claim their raw power by calling `.claimNFT()`. They then get allocated raw power in the vault and also receive an NFT. Claiming power does not raise an event.

Note that the total raw power is *not* the sum over the raw powers of all the users *that have claimed*. That is, unless all founding members claim, some power will be left unallocated.

Governance can also change people's multipliers later.

### Associated DAOs Vault
The associated DAOs vault is simple: Governance simply assigns a certain amount of power to some address. These addresses belong to other DAOs (i.e., DAOs have to go through their own governance process to vote in the Gyro governance system).

- Total raw voting power = set by governance
- Individual raw voting power = set by governance

Power is updated via a call to `.updateDAOAndTotalWeight()`. (callable by Gyro governance only)

I *think* for this vault we do have that total raw voting power = SUM(individual voting powers) but this is not enforced on a smart-contract level.
### Councillor NFT Vault
This is similar to the founding members vault, but the claiming procedure, and its dynamics are different. We have a list of (address, multiplier) values that are allowed to claim voting power (like in the founding members vault). Different to the founding members vault, there is a limited supply of "Councillor NFTs" (specifically `CouncillorNFT.maxSupply = 196`). Only the first 196 people can claim voting power, afterwards, the claiming fails. 

- Total raw voting power = SUM(individual raw powers) at all times (different form the founding members vault!)
- Individual raw voting power = the multiplier in the table.

Users claim raw power via `CouncillorNFT.mint()`. (this is not a function of the vault, but of the NFT contract; it will call into the vault to actually allocate the voting power) This raises a `Transfer` event but this event doesn't contain the multiplier, so it's probably best to look at calls to `.mint()` directly. `.mint()` also allows to delegate in the same step (see below)

### Aggregate LP Vault
This is a "meta" vault summarizing the voting power of liquidity providers in the GYD secondary market. Each secondary market (ECLP) has an *LP Vault* associated and the Aggregate LP Vault manages the voting power arising from all LP Vaults together.

Each LP Vault has a weight in the Aggregate LP Vault.  Governance can update the LP Vaults and the weights by calling `.setVaultWeights()` and the list of vaults can be queried on-chain using `.getVaultWeights()`.

- Total raw power = MAX(`AggregateLPVault.threshold`, SUM(across LP vaults v: the total raw power of v * the weight of v))
- Individual raw power = SUM(across LP vaults v: the user's raw power in v * the weight of v)

The value `AggregateLPVault.threshold` (currently = 10 million) is used to limit the power of LPers if they only contribute a small amount of assets.

#### LP Vault 
There are currently three LP Vaults (one per GYD ECLP) and each of them works as follows. (the name of this contract is `LockedVault`, not `LPVault` b/c the code is re-used for the GYFI vault) Note that the LP Vaults do *not* count as "voting vaults" at the top level but are instead subordinate to the Aggregate LP Vault. 

To claim voting power, LPers must lock their LP shares into the vault. They can only withdraw their LP shares (losing their voting power) with a time delay. This is to ensure that they they vote in the long- (or at least medium-) term interest of the project.

- Total raw power = the total amount of LP shares locked in the vault (for which withdrawal has not been initiated)
- Individual raw power = the amount of LP shares that the LPers has locked in the vault (for which withdrawal has not been initiated)

To claim voting powers, LPers call `.deposit()`. They can also immediately delegate their voting power.

To withdraw their assets and lose their voting power, LPers call `.initiateWithdrawal()`. If they have delegated, they can also specify from which delegate the power should be removed. This immediately reduces their voting power. They later have to call `.withdraw()` to actually get their LP tokens back.

LPers can optionally receive a reward for the period that they have their LP tokens locked.

### GYFI Vault
The GYFI vault works similarly to a single LP vault but without an "AggregateGYFIVault". Instead, all the functionality is implemented directly in the GYFI vault itself. The name of the contract is `LockedVaultWithThreshold` because some code is re-used.

- Total raw power = MAX(`.threshold`, total GYFI locked in the vault for which withdrawal has not been initiated)
- Individual raw power = amount of the user's GYFI locked in the vault for which withdrawal has not been initiated.

The purpose of the `threshold` is again to limit the power of this vault if only a small amount of GYFI has been locked.

The process for claiming / returning voting power is the same as for the LP Vaults.

## Across Vaults
A user's voting power across vaults is computed as a weighted sum.

At any point in time, each vault has a *weight* so that all weights sum to 1. Weights are not constant over time, but vary according to a *schedule* (see `VotingPowerAggregator.listVaults()` and `VotingPowerAggregator.scheduleStartsAt` and `.scheduleEndsAt`). Currently, this schedule is configured to run across 4 years following the initial deployment of the governance system. Governance can update the schedule by calling `VotingPowerAggregator.setSchedule()`.

The voting power of an individual user is a number between 0 and 1 (i.e., a percentage) and is equal to

SUM(across (top-level) voting vaults v: the user's raw power in vault v / total raw power of vault v * current weight of vault v)

The sum of all users' voting powers is guaranteed to be ≤ 1. It may be < 1 if some vaults leave some raw voting power unallocated (see above).

## Delegation
All vaults support *delegation*, i.e., a user A can delegate its raw power to another user B. This means that user A will be able to use less raw power to vote and B will have more.

Delegation happens on the level of raw power *within* an individual vault: users cannot delegate across vaults. It does not matter if user B had power in that vault before. For example, a founding member can delegate to some other addres that may itself not be a founding member.

Delegation / undoing delegation emits events `VotesDelegated` and `VotesUndelegated`.

## History / Snapshots
Vaults store all changes to a user's voting power and delegation in a history data structure. When a user votes for a proposal, their voting power is taken *at the time the proposal was created*, rather than at the time they vote. This is important to prevent "double voting" where users shift their voting power around during the voting period.

The functions `VotingPowerAggregator.getVotingPower()` and `(some vault).getRawVotingPower()` take an optional `timestamp` parameter that can be used to access the historical values.
