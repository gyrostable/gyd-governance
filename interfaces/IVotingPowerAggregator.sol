// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "../libraries/DataTypes.sol";

interface IVotingPowerAggregator {
    function getVotingPower(
        address account
    ) external view returns (DataTypes.VaultVotingPower[] memory);

    function calculateWeightedPowerPct(
        DataTypes.VaultVotingPower[] calldata vaultVotingPowers
    ) external view returns (uint256);

    function listVaults()
        external
        view
        returns (DataTypes.VaultWeight[] memory);

    function getVaultWeight(address vault) external view returns (uint256);

    function setSchedule(
        DataTypes.VaultWeightConfiguration[] memory vaults,
        uint256 _scheduleStartsAt,
        uint256 _scheduleEndsAt
    ) external;
}
