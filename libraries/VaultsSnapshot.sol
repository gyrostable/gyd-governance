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

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "./DataTypes.sol";
import "./ScaledMath.sol";

library VaultsSnapshot {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using ScaledMath for uint256;

    function getBallotPercentage(
        DataTypes.VaultSnapshot[] memory snapshots,
        EnumerableMap.AddressToUintMap storage vaultPowers
    ) internal view returns (uint256 votingPowerPct) {
        for (uint256 i; i < snapshots.length; i++) {
            DataTypes.VaultSnapshot memory snapshot = snapshots[i];
            (, uint256 ballotPower) = vaultPowers.tryGet(snapshot.vaultAddress);
            votingPowerPct += ballotPower
                .divDown(snapshot.totalVotingPower)
                .mulDown(snapshot.weight);
        }
    }

    /// @dev this simply appends, so the storage must be clean
    function persist(
        DataTypes.VaultSnapshot[] memory snapshots,
        DataTypes.VaultSnapshot[] storage cleanStorage
    ) internal {
        require(cleanStorage.length == 0, "storage must be clean");
        for (uint256 i; i < snapshots.length; i++) {
            cleanStorage.push(snapshots[i]);
        }
    }
}
