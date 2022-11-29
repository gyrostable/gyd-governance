// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../interfaces/IVault.sol";
import "../libraries/DataTypes.sol";
import "../libraries/ScaledMath.sol";
import "./access/ImmutableOwner.sol";

contract AggregateLPVault is IVault, ImmutableOwner {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using ScaledMath for uint256;

    EnumerableMap.AddressToUintMap internal vaultsToWeights;

    uint256 internal threshold;

    constructor(address _owner, uint256 _threshold) ImmutableOwner(_owner) {
        threshold = _threshold;
    }

    function setVaultWeights(
        DataTypes.VaultWeight[] calldata vaultWeights
    ) external onlyOwner {
        _removeAllVaultWeights();

        for (uint256 i = 0; i < vaultWeights.length; i++) {
            DataTypes.VaultWeight memory v = vaultWeights[i];
            require(v.weight > 0, "cannot have a 0 weight");
        }

        for (uint256 i = 0; i < vaultWeights.length; i++) {
            DataTypes.VaultWeight memory v = vaultWeights[i];
            vaultsToWeights.set(v.vaultAddress, v.weight);
        }
    }

    function _removeAllVaultWeights() internal {
        for (uint256 i = 0; i < vaultsToWeights.length(); i++) {
            (address key, ) = vaultsToWeights.at(i);
            vaultsToWeights.remove(key);
        }
    }

    function setThreshold(uint256 _threshold) external onlyOwner {
        threshold = _threshold;
    }

    function getRawVotingPower(address _user) external view returns (uint256) {
        uint256 rawVotingPower = 0;
        for (uint256 i = 0; i < vaultsToWeights.length(); i++) {
            (address vault, uint256 price) = vaultsToWeights.at(i);
            rawVotingPower += IVault(vault).getRawVotingPower(_user).mulDown(
                price
            );
        }

        return rawVotingPower;
    }

    function getTotalRawVotingPower() external view returns (uint256) {
        uint256 totalRawVotingPower = 0;
        for (uint256 i = 0; i < vaultsToWeights.length(); i++) {
            (address vault, uint256 price) = vaultsToWeights.at(i);
            totalRawVotingPower += IVault(vault)
                .getTotalRawVotingPower()
                .mulDown(price);
        }

        if (totalRawVotingPower <= threshold) {
            totalRawVotingPower = threshold;
        }

        return totalRawVotingPower;
    }
}
