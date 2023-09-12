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

import "../../interfaces/IVotingPowerAggregator.sol";
import "../../libraries/DataTypes.sol";

contract MockVotingPowerAggregator is IVotingPowerAggregator {
    uint256 public votingPower;
    uint256 public totalVotingPower;
    uint256 public weightedPowerPct;

    constructor(
        uint256 _votingPower,
        uint256 _totalVotingPower,
        uint256 _weightedPowerPct
    ) {
        votingPower = _votingPower;
        totalVotingPower = _totalVotingPower;
        weightedPowerPct = _weightedPowerPct;
    }

    function createVaultsSnapshot()
        external
        view
        returns (DataTypes.VaultSnapshot[] memory snapshots)
    {
        snapshots = new DataTypes.VaultSnapshot[](1);
        snapshots[0] = DataTypes.VaultSnapshot({
            vaultAddress: address(0x1),
            weight: 1e18,
            totalVotingPower: totalVotingPower
        });
    }

    function setVotingPower(uint256 _votingPower) public {
        votingPower = _votingPower;
    }

    function getVotingPower(
        address,
        uint256 /* timestamp */,
        address[] memory /* useSnapshot */
    ) public view returns (DataTypes.VaultVotingPower[] memory) {
        DataTypes.VaultVotingPower[]
            memory vp = new DataTypes.VaultVotingPower[](1);
        vp[0] = DataTypes.VaultVotingPower({
            vaultAddress: address(0x1),
            votingPower: votingPower
        });
        return vp;
    }

    function getVotingPower(
        address account,
        uint256 timestamp
    ) external view returns (DataTypes.VaultVotingPower[] memory) {
        return getVotingPower(account, timestamp, new address[](0));
    }

    function getTotalVotingPower() external view returns (uint256) {
        return totalVotingPower;
    }

    function calculateWeightedPowerPct(
        DataTypes.VaultVotingPower[] memory vaults
    ) external view returns (uint256) {
        if (vaults.length == 0) {
            return 0;
        }
        return weightedPowerPct;
    }

    function getVaultWeight(address) external pure returns (uint256) {
        revert("not implemented");
    }

    function listVaults()
        external
        pure
        returns (DataTypes.VaultWeight[] memory)
    {
        revert("not implemented");
    }

    function setSchedule(
        DataTypes.VaultWeightSchedule calldata // schedule
    ) external {
        revert("not implemented");
    }
}
