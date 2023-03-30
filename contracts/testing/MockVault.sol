// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../interfaces/IVault.sol";
import "../vaults/BaseVault.sol";

contract MockVault is BaseVault {
    uint256 public rawVotingPower;
    uint256 public totalRawVotingPower;

    constructor(
        address _votingPowerAggregator,
        uint256 _rawVotingPower,
        uint256 _totalRawVotingPower
    ) BaseVault(_votingPowerAggregator) {
        rawVotingPower = _rawVotingPower;
        totalRawVotingPower = _totalRawVotingPower;
    }

    function getRawVotingPower(
        address /* user */,
        uint256 /* timestamp */
    ) public view override returns (uint256) {
        return rawVotingPower;
    }

    function getTotalRawVotingPower() public view override returns (uint256) {
        return totalRawVotingPower;
    }
}
