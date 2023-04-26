// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./access/ImmutableOwner.sol";

import "../libraries/VaultsSnapshot.sol";
import "../libraries/Errors.sol";
import "../libraries/ScaledMath.sol";

import "../interfaces/IVotingPowerAggregator.sol";
import "../interfaces/IVault.sol";

contract VotingPowerAggregator is IVotingPowerAggregator, ImmutableOwner {
    using ScaledMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using VaultsSnapshot for VaultsSnapshot.Snapshot;

    EnumerableSet.AddressSet internal _authorizedToSnapshot;
    EnumerableSet.AddressSet internal _vaultAddresses;
    mapping(address => DataTypes.VaultWeightConfiguration) internal _vaults;
    mapping(uint256 => VaultsSnapshot.Snapshot) internal _vaultSnapshots;

    uint256 public scheduleStartsAt;
    uint256 public scheduleEndsAt;

    constructor(address _owner) ImmutableOwner(_owner) {}

    function snapshotVaults() external {
        if (!_authorizedToSnapshot.contains(msg.sender))
            revert Errors.NotAuthorized(msg.sender, address(this));

        uint256 len = _vaultAddresses.length();
        for (uint256 i = 0; i < len; i++) {
            _vaultSnapshots[block.timestamp].add(
                _makeVaultSnapshot(_vaultAddresses.at(i))
            );
        }
    }

    function _makeVaultSnapshot(
        address vaultAddress
    ) internal view returns (DataTypes.VaultSnapshot memory) {
        return
            DataTypes.VaultSnapshot({
                vaultAddress: vaultAddress,
                weight: getVaultWeight(vaultAddress),
                totalVotingPower: IVault(vaultAddress).getTotalRawVotingPower()
            });
    }

    function grantSnapshotRights(address account) external onlyOwner {
        _authorizedToSnapshot.add(account);
    }

    function getVotingPower(
        address account,
        uint256 timestamp
    ) external view returns (DataTypes.VaultVotingPower[] memory) {
        return getVotingPower(account, timestamp, true);
    }

    function getVotingPower(
        address account,
        uint256 timestamp,
        bool useVaultsSnapshot
    ) public view returns (DataTypes.VaultVotingPower[] memory) {
        address[] memory vaults = _getVaults(timestamp, useVaultsSnapshot);
        DataTypes.VaultVotingPower[]
            memory userVotingPower = new DataTypes.VaultVotingPower[](
                vaults.length
            );
        for (uint256 i; i < vaults.length; i++) {
            IVault vault = IVault(vaults[i]);
            uint256 userRawVotingPower = vault.getRawVotingPower(
                account,
                timestamp
            );
            userVotingPower[i] = DataTypes.VaultVotingPower({
                vaultAddress: address(vault),
                votingPower: userRawVotingPower
            });
        }

        return userVotingPower;
    }

    function calculateWeightedPowerPct(
        DataTypes.VaultVotingPower[] calldata vaultVotingPowers,
        uint256 timestamp
    ) external view returns (uint256) {
        uint256 votingPowerPct;

        for (uint256 i; i < vaultVotingPowers.length; i++) {
            DataTypes.VaultVotingPower memory vaultVP = vaultVotingPowers[i];
            if (timestamp == block.timestamp) {
                uint256 vaultWeight = getVaultWeight(vaultVP.vaultAddress);
                if (vaultWeight > 0) {
                    uint256 tvp = IVault(vaultVP.vaultAddress)
                        .getTotalRawVotingPower();
                    votingPowerPct += vaultVP.votingPower.divDown(tvp).mulDown(
                        vaultWeight
                    );
                }
            } else {
                DataTypes.VaultSnapshot memory snapshot = _vaultSnapshots[
                    timestamp
                ].get(vaultVP.vaultAddress);
                if (snapshot.weight > 0) {
                    votingPowerPct += vaultVP
                        .votingPower
                        .divDown(snapshot.totalVotingPower)
                        .mulDown(snapshot.weight);
                }
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

            uint256 vaultWeight = getVaultWeight(conf.vaultAddress);
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

    function blockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    function getVaultWeight(address vault) public view returns (uint256) {
        DataTypes.VaultWeightConfiguration memory vaultWeight = _vaults[vault];

        if (blockTimestamp() > scheduleEndsAt) {
            return vaultWeight.targetWeight;
        }

        if (blockTimestamp() < scheduleStartsAt) {
            return vaultWeight.initialWeight;
        }

        uint256 scheduleElapsedPct = (blockTimestamp() - scheduleStartsAt)
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
            _scheduleEndsAt > _scheduleStartsAt,
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

    function _getVaults(
        uint256 timestamp,
        bool useSnapshot
    ) internal view returns (address[] memory) {
        if (useSnapshot) {
            address[] memory vaults = _vaultSnapshots[timestamp]
                .vaults
                .values();
            if (vaults.length == 0)
                revert Errors.NoSnapshotAtTimestamp(timestamp);
            return vaults;
        }
        return _vaultAddresses.values();
    }

    function _removeAllVaults() internal {
        uint256 length = _vaultAddresses.length();
        for (uint256 i; i < length; i++) {
            address vaultAddress = _vaultAddresses.at(0);
            _vaultAddresses.remove(vaultAddress);
            delete _vaults[vaultAddress];
        }
    }
}
