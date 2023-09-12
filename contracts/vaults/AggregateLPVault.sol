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

import "../../interfaces/IVault.sol";
import "./VaultWithThreshold.sol";
import "../../libraries/ScaledMath.sol";
import "../access/ImmutableOwner.sol";
import "./BaseVault.sol";

contract AggregateLPVault is BaseVault, VaultWithThreshold, ImmutableOwner {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using ScaledMath for uint256;

    string internal constant _VAULT_TYPE = "AggregateLP";

    struct VaultWeight {
        address vaultAddress;
        uint256 weight;
    }

    EnumerableMap.AddressToUintMap internal vaultsToWeights;

    constructor(
        address _owner,
        uint256 _threshold,
        VaultWeight[] memory vaultWeights
    ) ImmutableOwner(_owner) {
        threshold = _threshold;
        _setVaultWeights(vaultWeights);
    }

    function setVaultWeights(
        VaultWeight[] calldata vaultWeights
    ) external onlyOwner {
        _removeAllVaultWeights();
        _setVaultWeights(vaultWeights);
    }

    function getVaultWeights() external view returns (VaultWeight[] memory) {
        uint256 length = vaultsToWeights.length();
        VaultWeight[] memory vaultWeights = new VaultWeight[](length);

        for (uint256 i = 0; i < length; i++) {
            (address vault, uint256 weight) = vaultsToWeights.at(i);
            vaultWeights[i] = VaultWeight(vault, weight);
        }

        return vaultWeights;
    }

    function _removeAllVaultWeights() internal {
        uint256 length = vaultsToWeights.length();
        for (uint256 i = 0; i < length; i++) {
            (address key, ) = vaultsToWeights.at(0);
            vaultsToWeights.remove(key);
        }
    }

    function getRawVotingPower(
        address _user,
        uint256 timestamp
    ) public view override returns (uint256) {
        uint256 rawVotingPower = 0;
        for (uint256 i = 0; i < vaultsToWeights.length(); i++) {
            (address vault, uint256 weight) = vaultsToWeights.at(i);
            rawVotingPower += IVault(vault)
                .getRawVotingPower(_user, timestamp)
                .mulDown(weight);
        }

        return rawVotingPower;
    }

    function getTotalRawVotingPower() public view override returns (uint256) {
        uint256 totalRawVotingPower = 0;
        for (uint256 i = 0; i < vaultsToWeights.length(); i++) {
            (address vault, uint256 weight) = vaultsToWeights.at(i);
            totalRawVotingPower += IVault(vault)
                .getTotalRawVotingPower()
                .mulDown(weight);
        }

        if (totalRawVotingPower <= threshold) {
            totalRawVotingPower = threshold;
        }

        return totalRawVotingPower;
    }

    function getVaultType() external pure returns (string memory) {
        return _VAULT_TYPE;
    }

    function _setVaultWeights(VaultWeight[] memory vaultWeights) internal {
        for (uint256 i; i < vaultWeights.length; i++) {
            VaultWeight memory v = vaultWeights[i];
            require(v.weight > 0, "cannot have a 0 weight");
            vaultsToWeights.set(v.vaultAddress, v.weight);
        }
    }
}
