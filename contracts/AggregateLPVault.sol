// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../interfaces/IVault.sol";
import "../libraries/DataTypes.sol";
import "./access/ImmutableOwner.sol";

contract AggregateLPVault is IVault, ImmutableOwner {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap internal vaultsToPrices;

    uint256 internal threshold;

    constructor(address _owner, uint256 _threshold) ImmutableOwner(_owner) {
        threshold = _threshold;
    }

    function setVaultPrices(
        DataTypes.VaultPrice[] calldata vaultPrices
    ) external onlyOwner {
        _removeAllVaultPrices();

        for (uint256 i = 0; i < vaultPrices.length; i++) {
            DataTypes.VaultPrice memory v = vaultPrices[i];
            require(v.sharePrice > 0, "cannot have a 0 sharePrice");
        }

        for (uint256 i = 0; i < vaultPrices.length; i++) {
            DataTypes.VaultPrice memory v = vaultPrices[i];
            vaultsToPrices.set(v.vaultAddress, v.sharePrice);
        }
    }

    function _removeAllVaultPrices() internal {
        for (uint256 i = 0; i < vaultsToPrices.length(); i++) {
            (address key, ) = vaultsToPrices.at(i);
            vaultsToPrices.remove(key);
        }
    }

    function setThreshold(uint256 _threshold) external onlyOwner {
        threshold = _threshold;
    }

    function getRawVotingPower(address _user) external view returns (uint256) {
        uint256 rawVotingPower = 0;
        for (uint256 i = 0; i < vaultsToPrices.length(); i++) {
            (address vault, uint256 price) = vaultsToPrices.at(i);
            rawVotingPower += IVault(vault).getRawVotingPower(_user) * price;
        }

        return rawVotingPower;
    }

    function getTotalRawVotingPower() external view returns (uint256) {
        uint256 totalRawVotingPower = 0;
        for (uint256 i = 0; i < vaultsToPrices.length(); i++) {
            (address vault, uint256 price) = vaultsToPrices.at(i);
            totalRawVotingPower +=
                IVault(vault).getTotalRawVotingPower() *
                price;
        }

        if (totalRawVotingPower <= threshold) {
            totalRawVotingPower = threshold;
        }

        return totalRawVotingPower;
    }
}
