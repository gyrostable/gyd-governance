// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

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

    uint24 public proposalsCount;
    IWrappedERC20WithEMA internal wGYD;

    DataTypes.LimitUpgradeabilityParameters limitUpgradeabilityParams;

    EnumerableSet.Bytes32Set internal _activeProposals;
    EnumerableSet.Bytes32Set internal _timelockedProposals;
    mapping(uint24 => DataTypes.Proposal) internal _proposals;

    mapping(address => mapping(uint24 => DataTypes.Vote)) internal _votes;
    mapping(uint24 => DataTypes.VoteTotals) internal _totals;

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

        uint256 rawPower = votingPowerAggregator.getVotingPower(msg.sender);
        uint256 totalPower = votingPowerAggregator.getTotalVotingPower();
        require(
            rawPower.divDown(totalPower) > tier.proposalThreshold,
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
        uint256 votingPower,
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

        uint256 vp = votingPowerAggregator.getVotingPower(msg.sender);

        DataTypes.VoteTotals storage currentTotals = _totals[proposalId];
        DataTypes.Vote storage existingVote = _votes[msg.sender][proposalId];

        // First, zero out the effect of any vote already cast by the voter.
        if (existingVote.ballot == DataTypes.Ballot.FOR) {
            currentTotals._for -= uint128(existingVote.votingPower);
        } else if (existingVote.ballot == DataTypes.Ballot.AGAINST) {
            currentTotals.against -= uint128(existingVote.votingPower);
        } else if (existingVote.ballot == DataTypes.Ballot.ABSTAIN) {
            currentTotals.abstentions -= uint128(existingVote.votingPower);
        }

        // Then update the record of this user's vote to the latest ballot and voting power
        existingVote.ballot = ballot;
        existingVote.votingPower = vp;

        // And, finally update running total
        if (ballot == DataTypes.Ballot.FOR) {
            currentTotals._for += uint128(vp);
        } else if (ballot == DataTypes.Ballot.AGAINST) {
            currentTotals.against += uint128(vp);
        } else if (ballot == DataTypes.Ballot.ABSTAIN) {
            currentTotals.abstentions += uint128(vp);
        }

        emit VoteCast(proposalId, msg.sender, ballot, vp, currentTotals);
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

        DataTypes.VoteTotals memory currentTotals = _totals[proposalId];

        uint256 tvp = votingPowerAggregator.getTotalVotingPower();

        uint256 combined = currentTotals._for +
            currentTotals.against +
            currentTotals.abstentions;
        if (combined.divDown(tvp) < proposal.quorum) {
            proposal.status = DataTypes.Status.Rejected;
            _activeProposals.remove(bytes32(bytes3(proposalId)));
            emit ProposalTallied(
                proposalId,
                proposal.status,
                DataTypes.ProposalOutcome.QUORUM_NOT_MET
            );
            return;
        }

        uint256 result = uint256(currentTotals._for).divDown(tvp);
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
