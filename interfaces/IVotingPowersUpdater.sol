// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

interface IVotingPowersUpdater {
    function updateBaseVotingPower(
        address user,
        address delegate,
        uint128 addedVotingPower
    ) external;
}
