// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RaisingERC20 is ERC20 {
    constructor() ERC20("MyToken", "MTK") {}

    function totalSupply() public view override returns (uint256) {
        revert("function raised exception");
        return 0;
    }
}
