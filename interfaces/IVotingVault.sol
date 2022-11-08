// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IVotingVault {
    function rawVotingPower(address user) external view returns (uint);

    function totalRawVotingPower() external view returns (uint);
}
