// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBoundedERC20WithEMA is IERC20 {
    function boundedPctEMA() external view returns (uint256);
}
