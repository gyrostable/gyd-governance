// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "../libraries/DataTypes.sol";

interface IGovernanceManager {
    function createProposal(
        DataTypes.ProposalAction[] calldata actions
    ) external;

    function vote(uint24 proposalId, DataTypes.Ballot ballot) external;

    function getVoteTotals(
        uint24 proposalId
    ) external view returns (DataTypes.VoteTotals memory);

    function tallyVote(uint24 proposalId) external;

    function getCurrentPercentages(
        uint24 proposalId
    ) external view returns (uint256 for_, uint256 against, uint256 abstain);

    function executeProposal(uint24 proposalId) external;

    function getBallot(
        address voter,
        uint24 proposalId
    ) external view returns (DataTypes.Ballot);

    function listActiveProposals()
        external
        view
        returns (DataTypes.Proposal[] memory);

    function listTimelockedProposals()
        external
        view
        returns (DataTypes.Proposal[] memory);
}
