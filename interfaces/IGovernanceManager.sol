// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.17;

import "../libraries/DataTypes.sol";

interface IGovernanceManager {
    function createProposal(
        DataTypes.ProposalAction[] calldata actions
    ) external;

    function vote(uint16 proposalId, DataTypes.Ballot ballot) external;

    function getVoteTotals(
        uint16 proposalId
    ) external view returns (DataTypes.VoteTotals memory);

    function tallyVote(uint16 proposalId) external;

    function getCurrentPercentages(
        uint16 proposalId
    ) external view returns (uint256 for_, uint256 against, uint256 abstain);

    function executeProposal(uint16 proposalId) external;

    function getBallot(
        address voter,
        uint16 proposalId
    ) external view returns (DataTypes.Ballot);

    function getProposal(
        uint16 proposalId
    ) external view returns (DataTypes.Proposal memory);

    function listActiveProposals()
        external
        view
        returns (DataTypes.Proposal[] memory);

    function listTimelockedProposals()
        external
        view
        returns (DataTypes.Proposal[] memory);
}
