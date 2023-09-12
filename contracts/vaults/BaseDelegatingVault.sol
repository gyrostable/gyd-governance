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

import "../../interfaces/IVault.sol";
import "../../interfaces/IDelegatingVault.sol";

import "./BaseVault.sol";

import "../../libraries/Errors.sol";
import "../../libraries/DataTypes.sol";
import "../../libraries/VotingPowerHistory.sol";

abstract contract BaseDelegatingVault is BaseVault, IDelegatingVault {
    using VotingPowerHistory for VotingPowerHistory.History;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // @notice A record of delegates per account
    // this is the current delegates (not snapshot) and
    // is only used to allow this information to be retrived (e.g. by the frontend)
    mapping(address => EnumerableMap.AddressToUintMap)
        internal _currentDelegations;

    function delegateVote(address _delegate, uint256 _amount) external {
        _delegateVote(msg.sender, _delegate, _amount);
    }

    function undelegateVote(address _delegate, uint256 _amount) external {
        _undelegateVote(msg.sender, _delegate, _amount);
    }

    function changeDelegate(
        address _oldDelegate,
        address _newDelegate,
        uint256 _amount
    ) external {
        _undelegateVote(msg.sender, _oldDelegate, _amount);
        _delegateVote(msg.sender, _newDelegate, _amount);
    }

    function getDelegations(
        address account
    ) external view returns (DataTypes.Delegation[] memory delegations) {
        EnumerableMap.AddressToUintMap storage delegates = _currentDelegations[
            account
        ];
        uint256 len = delegates.length();
        delegations = new DataTypes.Delegation[](len);
        for (uint256 i = 0; i < len; i++) {
            (address delegate, uint256 amount) = delegates.at(i);
            delegations[i] = DataTypes.Delegation(delegate, amount);
        }
        return delegations;
    }

    function _delegateVote(address from, address to, uint256 amount) internal {
        history.delegateVote(from, to, amount);
        (bool exists, uint256 current) = _currentDelegations[from].tryGet(to);
        uint256 newAmount = exists ? current + amount : amount;
        _currentDelegations[from].set(to, newAmount);
    }

    function _undelegateVote(
        address from,
        address to,
        uint256 amount
    ) internal {
        history.undelegateVote(from, to, amount);
        uint256 current = _currentDelegations[from].get(to);
        if (current == amount) {
            _currentDelegations[from].remove(to);
        } else {
            // amount < current
            _currentDelegations[from].set(to, current - amount);
        }
    }
}
