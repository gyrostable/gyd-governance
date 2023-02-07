// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../interfaces/IVotingPowerAggregator.sol";
import "../../libraries/DataTypes.sol";

contract MockVotingPowerAggregator is IVotingPowerAggregator {
    uint256 public votingPower;
    uint256 public totalVotingPower;

    constructor(uint256 _votingPower, uint256 _totalVotingPower) {
        votingPower = _votingPower;
        totalVotingPower = _totalVotingPower;
    }

    function setVotingPower(uint256 _votingPower) public {
        votingPower = _votingPower;
    }

    function getVotingPower(address) external view returns (uint256) {
        return votingPower;
    }

    function getTotalVotingPower() external view returns (uint256) {
        return totalVotingPower;
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
        DataTypes.VaultWeightConfiguration[] memory,
        uint256,
        uint256
    ) external {
        revert("not implemented");
    }
}
