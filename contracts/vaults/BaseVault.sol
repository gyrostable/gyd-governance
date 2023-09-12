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

import "../../libraries/Errors.sol";
import "../../libraries/DataTypes.sol";
import "../../libraries/VotingPowerHistory.sol";

abstract contract BaseVault is IVault {
    using VotingPowerHistory for VotingPowerHistory.History;

    VotingPowerHistory.History internal history;

    function getCurrentRecord(
        address account
    ) external view returns (VotingPowerHistory.Record memory) {
        return history.currentRecord(account);
    }

    function getRawVotingPower(
        address account
    ) external view returns (uint256) {
        return getRawVotingPower(account, block.timestamp);
    }

    function getRawVotingPower(
        address account,
        uint256 timestamp
    ) public view virtual returns (uint256);
}
