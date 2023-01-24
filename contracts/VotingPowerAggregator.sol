// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

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
    mapping(address => DataTypes.VaultWeightConfiguration) internal _vaults;

    uint256 public scheduleStartsAt;
    uint256 public scheduleEndsAt;

    constructor(address _owner) ImmutableOwner(_owner) {}

    function getVotingPower(
        address account
    ) external view returns (DataTypes.VaultVotingPower[] memory) {
        uint256 vaultsCount = _vaultAddresses.length();
        DataTypes.VaultVotingPower[]
            memory userVotingPower = new DataTypes.VaultVotingPower[](
                vaultsCount
            );
        for (uint256 i; i < vaultsCount; i++) {
            IVault vault = IVault(_vaultAddresses.at(i));
            uint256 userRawVotingPower = vault.getRawVotingPower(account);
            userVotingPower[i] = DataTypes.VaultVotingPower({
                vaultAddress: _vaultAddresses.at(i),
                votingPower: userRawVotingPower
            });
        }

        return userVotingPower;
    }

    function calculateWeightedPowerPct(
        DataTypes.VaultVotingPower[] calldata vaultVotingPowers
    ) external view returns (uint256) {
        uint256 votingPowerPct;

        for (uint256 i; i < vaultVotingPowers.length; i++) {
            DataTypes.VaultVotingPower memory vaultVP = vaultVotingPowers[i];
            uint256 vaultWeight = this.getVaultWeight(vaultVP.vaultAddress);
            if (vaultWeight != 0) {
                uint256 tvp = IVault(vaultVP.vaultAddress)
                    .getTotalRawVotingPower();
                votingPowerPct += vaultVP.votingPower.divDown(tvp).mulDown(
                    vaultWeight
                );
            }
        }

        return votingPowerPct;
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
        uint256 totalWeight;
        for (uint256 i; i < length; i++) {
            DataTypes.VaultWeightConfiguration memory conf = _vaults[
                _vaultAddresses.at(i)
            ];
            vaults[i].vaultAddress = conf.vaultAddress;
            vaults[i].initialWeight = conf.initialWeight;
            vaults[i].targetWeight = conf.targetWeight;

            uint256 vaultWeight = this.getVaultWeight(conf.vaultAddress);
            vaults[i].currentWeight = vaultWeight;

            totalWeight += vaultWeight;
        }

        // Normalize
        for (uint256 i; i < length; i++) {
            vaults[i].currentWeight = vaults[i].currentWeight.divDown(
                totalWeight
            );
        }

        return vaults;
    }

    function getVaultWeight(address vault) external view returns (uint256) {
        DataTypes.VaultWeightConfiguration memory vaultWeight = _vaults[vault];

        if (block.timestamp > scheduleEndsAt) {
            return vaultWeight.targetWeight;
        }

        if (block.timestamp < scheduleStartsAt) {
            return vaultWeight.initialWeight;
        }

        uint256 scheduleElapsedPct = (block.timestamp - scheduleStartsAt)
            .divDown(scheduleEndsAt - scheduleStartsAt);

        uint256 currentWeight;
        if (vaultWeight.targetWeight > vaultWeight.initialWeight) {
            uint256 absWeightChange = vaultWeight.targetWeight -
                vaultWeight.initialWeight;
            currentWeight =
                vaultWeight.initialWeight +
                absWeightChange.mulDown(scheduleElapsedPct);
        } else {
            uint256 absWeightChange = vaultWeight.initialWeight -
                vaultWeight.targetWeight;
            currentWeight =
                vaultWeight.initialWeight -
                absWeightChange.mulDown(scheduleElapsedPct);
        }
        return currentWeight;
    }

    function setSchedule(
        DataTypes.VaultWeightConfiguration[] calldata vaults,
        uint256 _scheduleStartsAt,
        uint256 _scheduleEndsAt
    ) external onlyOwner {
        require(
            _scheduleEndsAt >= _scheduleStartsAt,
            "schedule must end after it begins"
        );

        scheduleStartsAt = _scheduleStartsAt;
        scheduleEndsAt = _scheduleEndsAt;

        _removeAllVaults();

        uint256 totalInitialWeight;
        uint256 totalTargetWeight;

        for (uint256 i; i < vaults.length; i++) {
            DataTypes.VaultWeightConfiguration calldata vault = vaults[i];
            _addVault(vault);
            totalInitialWeight += vault.initialWeight;
            totalTargetWeight += vault.targetWeight;
        }

        if (totalInitialWeight != ScaledMath.ONE)
            revert Errors.InvalidTotalWeight(totalInitialWeight);

        if (totalTargetWeight != ScaledMath.ONE)
            revert Errors.InvalidTotalWeight(totalTargetWeight);
    }

    function _addVault(
        DataTypes.VaultWeightConfiguration calldata vault
    ) internal {
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
