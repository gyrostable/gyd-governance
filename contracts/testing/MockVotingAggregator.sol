// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../interfaces/IVotingPowerAggregator.sol";
import "../../libraries/DataTypes.sol";

contract MockVotingPowerAggregator is IVotingPowerAggregator {
    uint256 public votingPower;
    uint256 public totalVotingPower;
    uint256 public weightedPowerPct;

    constructor(
        uint256 _votingPower,
        uint256 _totalVotingPower,
        uint256 _weightedPowerPct
    ) {
        votingPower = _votingPower;
        totalVotingPower = _totalVotingPower;
        weightedPowerPct = _weightedPowerPct;
    }

    function snapshotVaults() external override {}

    function setVotingPower(uint256 _votingPower) public {
        votingPower = _votingPower;
    }

    function getVotingPower(
        address,
        uint256 /* timestamp */,
        bool /* useSnapshot */
    ) public view returns (DataTypes.VaultVotingPower[] memory) {
        DataTypes.VaultVotingPower[]
            memory vp = new DataTypes.VaultVotingPower[](1);
        vp[0] = DataTypes.VaultVotingPower({
            vaultAddress: address(0x1),
            votingPower: votingPower
        });
        return vp;
    }

    function getVotingPower(
        address account,
        uint256 timestamp
    ) external view returns (DataTypes.VaultVotingPower[] memory) {
        return getVotingPower(account, timestamp, true);
    }

    function getTotalVotingPower() external view returns (uint256) {
        return totalVotingPower;
    }

    function calculateWeightedPowerPct(
        DataTypes.VaultVotingPower[] memory vaults,
        uint256 /* timestamp */
    ) external view returns (uint256) {
        if (vaults.length == 0) {
            return 0;
        }
        return weightedPowerPct;
    }

    function getVaultWeight(address) external view returns (uint256) {
        revert("not implemented");
    }

    function listVaults()
        external
        view
        returns (DataTypes.VaultWeight[] memory)
    {
        revert("not implemented");
    }

    function setSchedule(
        DataTypes.VaultWeightSchedule calldata schedule
    ) external {
        revert("not implemented");
    }
}
