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

interface IVotingPowerAggregator {
    function createVaultsSnapshot()
        external
        view
        returns (DataTypes.VaultSnapshot[] memory snapshots);

    function getVotingPower(
        address account,
        uint256 timestamp
    ) external view returns (DataTypes.VaultVotingPower[] memory);

    function getVotingPower(
        address account,
        uint256 timestamp,
        address[] memory vaults
    ) external view returns (DataTypes.VaultVotingPower[] memory);

    function calculateWeightedPowerPct(
        DataTypes.VaultVotingPower[] calldata vaultVotingPowers
    ) external view returns (uint256);

    function listVaults()
        external
        view
        returns (DataTypes.VaultWeight[] memory);

    function getVaultWeight(address vault) external view returns (uint256);

    function setSchedule(
        DataTypes.VaultWeightSchedule calldata schedule
    ) external;
}
