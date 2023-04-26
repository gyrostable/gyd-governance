// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./DataTypes.sol";

library VaultsSnapshot {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Snapshot {
        EnumerableSet.AddressSet vaults;
        mapping(address => DataTypes.VaultSnapshot) snapshots;
    }

    function add(
        Snapshot storage self,
        DataTypes.VaultSnapshot memory vault
    ) internal {
        self.vaults.add(vault.vaultAddress);
        self.snapshots[vault.vaultAddress] = vault;
    }

    function get(
        Snapshot storage self,
        address vaultAddress
    ) internal view returns (DataTypes.VaultSnapshot memory) {
        return self.snapshots[vaultAddress];
    }

    function listVaults(
        Snapshot storage self
    ) internal view returns (address[] memory) {
        return self.vaults.values();
    }
}
