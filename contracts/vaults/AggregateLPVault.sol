// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../../interfaces/IVault.sol";
import "../../libraries/ScaledMath.sol";
import "../access/ImmutableOwner.sol";
import "./BaseVault.sol";

contract AggregateLPVault is BaseVault, ImmutableOwner {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using ScaledMath for uint256;

    EnumerableMap.AddressToUintMap internal vaultsToWeights;

    uint256 internal threshold;

    constructor(address _owner, uint256 _threshold) ImmutableOwner(_owner) {
        threshold = _threshold;
    }

    struct VaultWeight {
        address vaultAddress;
        uint256 weight;
    }

    function setVaultWeights(
        VaultWeight[] calldata vaultWeights
    ) external onlyOwner {
        _removeAllVaultWeights();

        uint256 totalVoteWeights;

        for (uint256 i; i < vaultWeights.length; i++) {
            VaultWeight memory v = vaultWeights[i];
            require(v.weight > 0, "cannot have a 0 weight");
            vaultsToWeights.set(v.vaultAddress, v.weight);
            totalVoteWeights += v.weight;
        }

        if (totalVoteWeights != ScaledMath.ONE)
            revert Errors.InvalidTotalWeight(totalVoteWeights);
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

    function getRawVotingPower(
        address _user,
        uint256 timestamp
    ) public view override returns (uint256) {
        uint256 rawVotingPower = 0;
        for (uint256 i = 0; i < vaultsToWeights.length(); i++) {
            (address vault, uint256 price) = vaultsToWeights.at(i);
            rawVotingPower += IVault(vault)
                .getRawVotingPower(_user, timestamp)
                .mulDown(price);
        }

        return rawVotingPower;
    }

    function getTotalRawVotingPower() public view override returns (uint256) {
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
