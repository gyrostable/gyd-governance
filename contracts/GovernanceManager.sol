// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../libraries/DataTypes.sol";

import "../interfaces/IVotingPowerAggregator.sol";
import "../interfaces/ITierer.sol";

contract GovernanceManager {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    uint24 public proposalsCount;

    EnumerableSet.Bytes32Set internal _activeProposals;
    mapping(uint24 => DataTypes.Proposal) internal _proposals;

    mapping(address => mapping(uint24 => DataTypes.Vote)) internal _votes;
    mapping(uint24 => DataTypes.VoteTotals) internal _totals;

    IVotingPowerAggregator public votingPowerAggregator;
    ITierer public tierer;

    constructor(
        IVotingPowerAggregator _votingPowerAggregator,
        ITierer _tierer
    ) {
        votingPowerAggregator = _votingPowerAggregator;
        tierer = _tierer;
    }

    event ProposalCreated(
        uint24 id,
        address proposer,
        DataTypes.ProposalAction action
    );

    function createProposal(DataTypes.ProposalAction calldata action) external {
        DataTypes.Tier memory tier = tierer.getTier(action.target, action.data);

        uint256 rawPower = votingPowerAggregator.getVotingPower(msg.sender);
        uint256 currentTotal = votingPowerAggregator.getTotalVotingPower();
        uint256 fractionalPower = rawPower.divDown(currentTotal);
        if (fractionalPower < tier.proposalThreshold) {
            revert(
                "proposer doesn't have enough voting power to propose this action"
            );
        }

        DataTypes.Proposal memory proposal = DataTypes.Proposal({
            id: proposalsCount,
            proposer: msg.sender,
            createdAt: uint64(block.timestamp),
            status: DataTypes.Status.Active,
            action: action
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
        uint256 votingPower
    );

    function vote(uint24 proposalId, DataTypes.Ballot ballot) external {
        DataTypes.Proposal storage proposal = _proposals[proposalId];
        if (proposal.createdAt == uint64(0)) {
            revert("proposal does not exist");
        }

        require(
            ballot != DataTypes.Ballot.UNDEFINED,
            "ballot must be cast FOR or AGAINST"
        );

        uint256 vp = votingPowerAggregator.getVotingPower(msg.sender);

        DataTypes.VoteTotals storage currentTotals = _totals[proposalId];
        DataTypes.Vote storage existingVote = _votes[msg.sender][proposalId];

        // First, zero out the effect of any vote already cast by the voter.
        currentTotal.combined -= vote.votingPower;
        if (vote.ballot == DataTypes.Ballot.FOR) {
            currentTotal._for -= vote.votingPower;
        } else if (vote.ballot == DataTypes.Ballot.AGAINST) {
            currentTotal.against -= vote.votingPower;
        }

        // Then update the record of this user's vote to the latest ballot and voting power
        existingVote.ballot = ballot;
        existingVote.votingPower = vp;

        // And, finally update running total
        currentTotal.combined += vote.votingPower;
        if (ballot == DataTypes.Ballot.FOR) {
            currentTotal._for += vote.votingPower;
        } else if (vote.ballot == DataTypes.Ballot.AGAINST) {
            currentTotal.against += vote.votingPower;
        }

        emit VoteCast(proposalId, msg.sender, ballot, vp);
    }

    function listActiveProposals()
        external
        view
        returns (DataTypes.Proposal[] memory)
    {
        uint256 length = _activeProposals.length();
        DataTypes.Proposal[] memory proposals = new DataTypes.Proposal[](
            length
        );
        for (uint256 i = 0; i < length; i++) {
            proposals[i] = _proposals[uint24(bytes3(_activeProposals.at(i)))];
        }
        return proposals;
    }
}
