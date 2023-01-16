// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

interface IWrappedERC20WithEMA {
    function wrappedPctEMA() external view returns (uint256);
}
