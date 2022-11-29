// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../interfaces/IVault.sol";

contract MockVault is IVault {
    uint256 public rawVotingPower;
    uint256 public totalRawVotingPower;

    constructor(uint256 _rawVotingPower, uint256 _totalRawVotingPower) {
        rawVotingPower = _rawVotingPower;
        totalRawVotingPower = _totalRawVotingPower;
    }

    function getRawVotingPower(address user) external view returns (uint256) {
        return rawVotingPower;
    }

    function getTotalRawVotingPower() external view returns (uint256) {
        return totalRawVotingPower;
    }
}
