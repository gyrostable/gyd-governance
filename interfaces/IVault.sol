// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

interface IVault {
    function getRawVotingPower(address account) external view returns (uint256);

    function getRawVotingPower(
        address account,
        uint256 timestamp
    ) external view returns (uint256);

    function getTotalRawVotingPower() external view returns (uint256);
}
