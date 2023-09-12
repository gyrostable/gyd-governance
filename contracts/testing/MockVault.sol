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

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../vaults/BaseDelegatingVault.sol";
import "../../interfaces/IVault.sol";
import "../../interfaces/IDelegatingVault.sol";
import "../../libraries/VotingPowerHistory.sol";
import "../../libraries/DataTypes.sol";

contract MockVault is BaseDelegatingVault {
    using VotingPowerHistory for VotingPowerHistory.History;
    using VotingPowerHistory for VotingPowerHistory.Record;
    using ScaledMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    string internal constant _VAULT_TYPE = "Mock";

    uint256 public rawVotingPower;
    uint256 public totalRawVotingPower;

    EnumerableSet.AddressSet internal _admins;

    modifier onlyAdmin() {
        require(_admins.contains(msg.sender), "only admin");
        _;
    }

    constructor() {
        _admins.add(msg.sender);
    }

    function addAdmin(address _admin) external onlyAdmin {
        _admins.add(_admin);
    }

    function listAdmins() external view returns (address[] memory) {
        return _admins.values();
    }

    function updateVotingPower(
        address user,
        uint256 amount
    ) external onlyAdmin {
        VotingPowerHistory.Record memory currentVotingPower = history
            .currentRecord(user);
        totalRawVotingPower -= currentVotingPower.multiplier.mulDown(
            currentVotingPower.baseVotingPower
        );
        history.updateVotingPower(
            user,
            amount,
            currentVotingPower.multiplier,
            currentVotingPower.netDelegatedVotes
        );
        totalRawVotingPower += currentVotingPower.multiplier.mulDown(amount);
    }

    function getRawVotingPower(
        address user,
        uint256 timestamp
    ) public view override returns (uint256) {
        return history.getVotingPower(user, timestamp);
    }

    function getTotalRawVotingPower() public view override returns (uint256) {
        return totalRawVotingPower;
    }

    function getVaultType() external pure returns (string memory) {
        return _VAULT_TYPE;
    }
}
