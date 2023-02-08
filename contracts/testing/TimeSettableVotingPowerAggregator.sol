// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../VotingPowerAggregator.sol";

contract TimeSettableVotingPowerAggregator is VotingPowerAggregator {
    uint256 public currentTime;

    constructor(address _owner) VotingPowerAggregator(_owner) {
        currentTime = block.timestamp;
    }

    function setCurrentTime(uint256 ts) public {
        currentTime = ts;
    }

    function sleep(uint256 secs) public {
        currentTime += secs;
    }

    function blockTimestamp() internal override view returns (uint256) {
        return currentTime;
    }
}
