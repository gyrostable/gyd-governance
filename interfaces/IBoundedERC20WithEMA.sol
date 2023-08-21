// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

interface IBoundedERC20WithEMA {
    function boundedPctEMA() external view returns (uint256);
}
