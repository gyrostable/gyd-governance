// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IBoundedERC20WithEMA is IERC20Upgradeable {
    function boundedPctEMA() external view returns (uint256);
}
