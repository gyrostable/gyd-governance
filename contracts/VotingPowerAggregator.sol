// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./access/ImmutableOwner.sol";

import "../libraries/Errors.sol";
import "../libraries/ScaledMath.sol";

import "../interfaces/IVotingPowerAggregator.sol";
import "../interfaces/IVault.sol";

contract VotingPowerAggregator is IVotingPowerAggregator, ImmutableOwner {
    using ScaledMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal _vaultAddresses;
    mapping(address => DataTypes.VaultWeight) internal _vaults;

    constructor(address _owner) ImmutableOwner(_owner) {}

    function getVotingPower(address account) external view returns (uint256) {
        uint256 totalVotingPower;

        uint256 vaultsCount = _vaultAddresses.length();
        for (uint256 i; i < vaultsCount; i++) {
            IVault vault = IVault(_vaultAddresses.at(i));
            uint256 userRawVotingPower = vault.getRawVotingPower(account);
            uint256 vaultTotalVotingPower = vault.getTotalRawVotingPower();
            uint256 userVaultVotingPower = userRawVotingPower.divDown(
                vaultTotalVotingPower
            );
            uint256 vaultWeight = _vaults[address(vault)].weight;
            totalVotingPower += userVaultVotingPower.mulDown(vaultWeight);
        }

        return totalVotingPower;
    }

    function listVaults()
        external
        view
        returns (DataTypes.VaultWeight[] memory)
    {
        uint256 length = _vaultAddresses.length();
        DataTypes.VaultWeight[] memory vaults = new DataTypes.VaultWeight[](
            length
        );
        for (uint256 i; i < length; i++) {
            vaults[i] = _vaults[_vaultAddresses.at(i)];
        }
        return vaults;
    }

    function getVaultWeight(address vault) external view returns (uint256) {
        return _vaults[vault].weight;
    }

    function updateVaults(
        DataTypes.VaultWeight[] calldata vaults
    ) external onlyOwner {
        _removeAllVaults();

        uint256 totalWeight;

        for (uint256 i; i < vaults.length; i++) {
            DataTypes.VaultWeight calldata vault = vaults[i];
            _addVault(vault);
            totalWeight += vault.weight;
        }

        if (totalWeight != ScaledMath.ONE)
            revert Errors.InvalidTotalWeight(totalWeight);
    }

    function _addVault(DataTypes.VaultWeight calldata vault) internal {
        if (!_vaultAddresses.add(vault.vaultAddress))
            revert Errors.DuplicatedVault(vault.vaultAddress);
        _vaults[vault.vaultAddress] = vault;
    }

    function _removeAllVaults() internal {
        uint256 length = _vaultAddresses.length();
        for (uint256 i; i < length; i++) {
            address vaultAddress = _vaultAddresses.at(i);
            _vaultAddresses.remove(vaultAddress);
            delete _vaults[vaultAddress];
        }
    }
}
