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
    mapping(uint24 => DataTypes.VoteTotal) internal _totals;

    IVotingPowerAggregator public votingPowerAggregator;
    ITierer public tierer;

    constructor(IVotingPowerAggregator _votingPowerAggregator, ITierer _tierer) {
        votingPowerAggregator = _votingPowerAggregator;
        tierer = _tierer;
    }

    event ProposalCreated(uint24 id, address proposer, DataTypes.ProposalAction action);

    function createProposal(DataTypes.ProposalAction calldata action) external {
        tier = tierer.getTier(action.target, action.data);
        if (votingPowerAggregator.getVotingPower(msg.sender) < tier.proposalThreshold) {
            revert("proposer doesn't have enough voting power to propose this action");
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

    event VoteCast(uint24 proposalId, address voter, DataTypes.Ballot vote, uint256 votingPower);

    function vote(uint24 proposalId, DataTypes.Ballot vote) external {
        DataTypes.Proposal storage proposal = _proposals(proposalId);
        if (proposal.createdAt == uint64(0)) {
            revert("proposal does not exist");
        }

        uint256 vp = votingPowerAggregator.getVotingPower(msg.sender)
        // check if proposal is valid + active
        // determine how much voting power a user has
        // determine if user has already voted, and overwrite their vote
        // update the record of the vote
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
