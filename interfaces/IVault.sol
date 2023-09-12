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

import "../libraries/VotingPowerHistory.sol";

interface IVault {
    function getRawVotingPower(address account) external view returns (uint256);

    function getCurrentRecord(
        address account
    ) external view returns (VotingPowerHistory.Record memory);

    function getRawVotingPower(
        address account,
        uint256 timestamp
    ) external view returns (uint256);

    function getTotalRawVotingPower() external view returns (uint256);

    function getVaultType() external view returns (string memory);
}
