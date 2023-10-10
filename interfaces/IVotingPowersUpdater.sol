// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IVotingPowersUpdater {
    function updateBaseVotingPower(
        address user,
        address delegate,
        uint128 addedVotingPower
    ) external;
}
