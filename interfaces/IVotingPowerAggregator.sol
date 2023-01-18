// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "../libraries/DataTypes.sol";

interface IVotingPowerAggregator {
    function getVotingPower(address account) external view returns (uint256);

    function getTotalVotingPower() external view returns (uint256);

    function listVaults()
        external
        view
        returns (DataTypes.VaultWeight[] memory);

    function getVaultWeight(address vault) external view returns (uint256);

    function updateVaults(DataTypes.VaultWeight[] memory vault) external;
}