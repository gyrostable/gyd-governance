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

interface IDelegatingVault {
    function delegateVote(address _delegate, uint256 _amount) external;

    function undelegateVote(address _delegate, uint256 _amount) external;

    function changeDelegate(
        address _oldDelegate,
        address _newDelegate,
        uint256 _amount
    ) external;

    function getDelegations(
        address account
    ) external view returns (DataTypes.Delegation[] memory delegations);

    event VotesDelegated(address delegator, address delegate, uint amount);
    event VotesUndelegated(address delegator, address delegate, uint amount);
}
