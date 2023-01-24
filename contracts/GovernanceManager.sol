// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../libraries/DataTypes.sol";
import "../libraries/ScaledMath.sol";

import "../interfaces/IVotingPowerAggregator.sol";
import "../interfaces/ITierer.sol";
import "../interfaces/ITierStrategy.sol";
import "../interfaces/IWrappedERC20WithEMA.sol";

contract GovernanceManager {
    using Address for address;
    using ScaledMath for uint256;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    uint24 public proposalsCount;
    IWrappedERC20WithEMA internal wGYD;

    DataTypes.LimitUpgradeabilityParameters limitUpgradeabilityParams;

    EnumerableSet.Bytes32Set internal _activeProposals;
    EnumerableSet.Bytes32Set internal _timelockedProposals;
    mapping(uint24 => DataTypes.Proposal) internal _proposals;

    mapping(address => mapping(uint24 => DataTypes.Vote)) internal _votes;
    mapping(uint24 => mapping(DataTypes.Ballot => EnumerableMap.AddressToUintMap))
        internal _totals;

    IVotingPowerAggregator public votingPowerAggregator;
    ITierer public tierer;

    constructor(
        IVotingPowerAggregator _votingPowerAggregator,
        ITierer _tierer,
        DataTypes.LimitUpgradeabilityParameters memory _params,
        IWrappedERC20WithEMA _wGYD
    ) {
        votingPowerAggregator = _votingPowerAggregator;
        tierer = _tierer;
        limitUpgradeabilityParams = _params;
        wGYD = _wGYD;
    }

    event ProposalCreated(
        uint24 id,
        address proposer,
        DataTypes.ProposalAction action
    );

    function createProposal(DataTypes.ProposalAction calldata action) external {
        DataTypes.Tier memory tier = tierer.getTier(action.target, action.data);
        // If a sufficiently large amount of GYD is wrapped, this signifies that holders
        // are happy with the system and are against further high-level upgrades.
        // As a result, we should apply a higher tier if the proposed action has big impacts.
        if (
            wGYD.wrappedPctEMA() > limitUpgradeabilityParams.emaThreshold &&
            tier.actionLevel > limitUpgradeabilityParams.actionLevelThreshold
        ) {
            tier = limitUpgradeabilityParams.tierStrategy.getTier(action.data);
        }

        DataTypes.VaultVotingPower[] memory rawPower = votingPowerAggregator
            .getVotingPower(msg.sender);
        uint256 votingPowerPct = votingPowerAggregator
            .calculateWeightedPowerPct(rawPower);
        require(
            votingPowerPct > tier.proposalThreshold,
            "proposer doesn't have enough voting power to propose this action"
        );

        uint64 createdAt = uint64(block.timestamp);
        uint64 votingEndsAt = createdAt + tier.proposalLength;
        uint64 executableAt = votingEndsAt + tier.timeLockDuration;

        DataTypes.Proposal memory proposal = DataTypes.Proposal({
            id: proposalsCount,
            proposer: msg.sender,
            createdAt: createdAt,
            votingEndsAt: votingEndsAt,
            executableAt: executableAt,
            status: DataTypes.Status.Active,
            action: action,
            quorum: tier.quorum,
            voteThreshold: tier.voteThreshold
        });
        proposalsCount = proposal.id + 1;
        _activeProposals.add(bytes32(bytes3(proposal.id)));
        _proposals[proposal.id] = proposal;

        emit ProposalCreated(proposal.id, proposal.proposer, proposal.action);
    }

    event VoteCast(
        uint24 proposalId,
        address voter,
        DataTypes.Ballot vote,
        DataTypes.VaultVotingPower[] votingPower,
        DataTypes.VoteTotals voteTotals
    );

    function vote(uint24 proposalId, DataTypes.Ballot ballot) external {
        DataTypes.Proposal storage proposal = _proposals[proposalId];
        require(proposal.createdAt != 0, "proposal does not exist");

        require(
            proposal.votingEndsAt > uint64(block.timestamp),
            "voting is closed on this proposal"
        );

        require(
            ballot != DataTypes.Ballot.UNDEFINED,
            "ballot must be cast FOR, AGAINST, or ABSTAIN"
        );

        DataTypes.VaultVotingPower[] memory uvp = votingPowerAggregator
            .getVotingPower(msg.sender);

        DataTypes.Vote storage existingVote = _votes[msg.sender][proposalId];
        // First, zero out the effect of any vote already cast by the voter.
        for (uint256 i = 0; i < existingVote.vaults.length; i++) {
            DataTypes.VaultVotingPower memory vvp = existingVote.vaults[i];
            (, uint256 val) = _totals[proposalId][existingVote.ballot].tryGet(
                vvp.vaultAddress
            );
            _totals[proposalId][existingVote.ballot].set(
                vvp.vaultAddress,
                val - vvp.votingPower
            );
        }

        // Then update the record of this user's vote to the latest ballot and voting power
        existingVote.ballot = ballot;
        // Copy over the voting power
        _copyToStorage(existingVote.vaults, uvp);

        // And, finally update running total
        for (uint256 i = 0; i < uvp.length; i++) {
            DataTypes.VaultVotingPower memory vvp = uvp[i];
            (, uint256 val) = _totals[proposalId][existingVote.ballot].tryGet(
                vvp.vaultAddress
            );
            _totals[proposalId][existingVote.ballot].set(
                vvp.vaultAddress,
                val + vvp.votingPower
            );
        }

        emit VoteCast(
            proposalId,
            msg.sender,
            ballot,
            uvp,
            _toVoteTotals(_totals[proposalId])
        );
    }

    function _copyToStorage(
        DataTypes.VaultVotingPower[] storage existingVoteVaults,
        DataTypes.VaultVotingPower[] memory vaults
    ) internal {
        if (existingVoteVaults.length > vaults.length) {
            for (uint256 i = 0; i < vaults.length; i++) {
                existingVoteVaults[i] = DataTypes.VaultVotingPower({
                    vaultAddress: vaults[i].vaultAddress,
                    votingPower: vaults[i].votingPower
                });
            }

            for (
                uint256 i = vaults.length - 1;
                i < existingVoteVaults.length;
                i++
            ) {
                delete existingVoteVaults[i];
            }
        } else {
            for (uint256 i = 0; i < existingVoteVaults.length; i++) {
                existingVoteVaults[i] = DataTypes.VaultVotingPower({
                    vaultAddress: vaults[i].vaultAddress,
                    votingPower: vaults[i].votingPower
                });
            }

            uint256 startIdx = 0;
            if (existingVoteVaults.length > 0) {
                startIdx = existingVoteVaults.length;
            }

            for (uint256 i = startIdx; i < vaults.length; i++) {
                existingVoteVaults.push(
                    DataTypes.VaultVotingPower({
                        vaultAddress: vaults[i].vaultAddress,
                        votingPower: vaults[i].votingPower
                    })
                );
            }
        }
    }

    function _toVoteTotals(
        mapping(DataTypes.Ballot => EnumerableMap.AddressToUintMap)
            storage totals
    ) internal returns (DataTypes.VoteTotals memory) {
        EnumerableMap.AddressToUintMap storage forVotingPower = totals[
            DataTypes.Ballot.FOR
        ];
        DataTypes.VaultVotingPower[] memory forTotals = _toVotingPowers(
            forVotingPower
        );

        EnumerableMap.AddressToUintMap storage againstVotingPower = totals[
            DataTypes.Ballot.AGAINST
        ];
        DataTypes.VaultVotingPower[] memory againstTotals = _toVotingPowers(
            againstVotingPower
        );

        EnumerableMap.AddressToUintMap storage abstentionsVotingPower = totals[
            DataTypes.Ballot.ABSTAIN
        ];
        DataTypes.VaultVotingPower[] memory abstentionsTotals = _toVotingPowers(
            abstentionsVotingPower
        );

        return
            DataTypes.VoteTotals({
                _for: forTotals,
                against: againstTotals,
                abstentions: abstentionsTotals
            });
    }

    event ProposalTallied(
        uint24 proposalId,
        DataTypes.Status status,
        DataTypes.ProposalOutcome outcome
    );

    function tallyVote(uint24 proposalId) external {
        DataTypes.Proposal storage proposal = _proposals[proposalId];
        require(proposal.createdAt != 0, "proposal does not exist");

        require(
            _activeProposals.contains(bytes32(bytes3(proposalId))),
            "proposal is not currently active"
        );

        require(
            uint64(block.timestamp) > proposal.votingEndsAt,
            "voting is ongoing for this proposal"
        );

        uint256 forTotalPct = votingPowerAggregator.calculateWeightedPowerPct(
            _toVotingPowers(_totals[proposalId][DataTypes.Ballot.FOR])
        );
        uint256 againstTotalPct = votingPowerAggregator
            .calculateWeightedPowerPct(
                _toVotingPowers(_totals[proposalId][DataTypes.Ballot.AGAINST])
            );
        uint256 abstentionsTotalPct = votingPowerAggregator
            .calculateWeightedPowerPct(
                _toVotingPowers(_totals[proposalId][DataTypes.Ballot.ABSTAIN])
            );

        uint256 combinedPct = forTotalPct +
            againstTotalPct +
            abstentionsTotalPct;
        if (combinedPct < proposal.quorum) {
            proposal.status = DataTypes.Status.Rejected;
            _activeProposals.remove(bytes32(bytes3(proposalId)));
            emit ProposalTallied(
                proposalId,
                proposal.status,
                DataTypes.ProposalOutcome.QUORUM_NOT_MET
            );
            return;
        }

        uint256 result = 0;
        if (forTotalPct + againstTotalPct > 0) {
            result = forTotalPct.divDown(forTotalPct + againstTotalPct);
        }
        DataTypes.ProposalOutcome outcome = DataTypes.ProposalOutcome.UNDEFINED;
        if (result > proposal.voteThreshold) {
            proposal.status = DataTypes.Status.Queued;
            outcome = DataTypes.ProposalOutcome.SUCCESSFUL;
            _timelockedProposals.add(bytes32(bytes3(proposalId)));
        } else {
            proposal.status = DataTypes.Status.Rejected;
            outcome = DataTypes.ProposalOutcome.THRESHOLD_NOT_MET;
        }
        _activeProposals.remove(bytes32(bytes3(proposalId)));
        emit ProposalTallied(proposalId, proposal.status, outcome);
    }

    function _toVotingPowers(
        EnumerableMap.AddressToUintMap storage map
    ) internal view returns (DataTypes.VaultVotingPower[] memory) {
        DataTypes.VaultVotingPower[]
            memory vvps = new DataTypes.VaultVotingPower[](map.length());
        for (uint256 i = 0; i < map.length(); i++) {
            (address key, uint256 value) = map.at(i);
            vvps[i] = DataTypes.VaultVotingPower({
                vaultAddress: key,
                votingPower: value
            });
        }

        return vvps;
    }

    event ProposalExecuted(uint24 proposalId);

    function executeProposal(uint24 proposalId) external {
        DataTypes.Proposal storage proposal = _proposals[proposalId];
        if (proposal.createdAt == uint64(0)) {
            revert("proposal does not exist");
        }

        require(
            _timelockedProposals.contains(bytes32(bytes3(proposalId))) &&
                uint64(block.timestamp) > proposal.executableAt,
            "proposal must be queued and ready to execute"
        );

        DataTypes.ProposalAction memory action = proposal.action;
        action.target.functionCall(action.data, "proposal execution failed");
        proposal.status = DataTypes.Status.Executed;
        _timelockedProposals.remove(bytes32(bytes3(proposalId)));
        emit ProposalExecuted(proposalId);
    }

    function listActiveProposals()
        external
        view
        returns (DataTypes.Proposal[] memory)
    {
        return _listProposals(_activeProposals.values());
    }

    function listTimelockedProposals()
        external
        view
        returns (DataTypes.Proposal[] memory)
    {
        return _listProposals(_timelockedProposals.values());
    }

    function _listProposals(
        bytes32[] memory ids
    ) internal view returns (DataTypes.Proposal[] memory) {
        uint256 len = ids.length;
        DataTypes.Proposal[] memory proposals = new DataTypes.Proposal[](len);
        for (uint256 i = 0; i < len; i++) {
            proposals[i] = _proposals[uint24(bytes3(ids[i]))];
        }
        return proposals;
    }
}
