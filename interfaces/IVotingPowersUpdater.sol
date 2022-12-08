// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

interface IVotingPowersUpdater {
    function updateVotingPower(address user, uint256 addedVotingPower) external;
}
