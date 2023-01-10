// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../libraries/DataTypes.sol";

import "../interfaces/IVotingPowerAggregator.sol";

contract GovernanceManager {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    uint24 public proposalsCount;

    EnumerableSet.Bytes32Set internal _activeProposals;
    mapping(uint24 => DataTypes.Proposal) internal _proposals;

    IVotingPowerAggregator public votingPowerAggregator;

    constructor(IVotingPowerAggregator _votingPowerAggregator) {
        votingPowerAggregator = _votingPowerAggregator;
    }

    function createProposal(DataTypes.ProposalAction calldata action) external {
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
