// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20Mintable is ERC20, Ownable {
    uint8 private _decimals;

    constructor() ERC20("MyToken", "MTK") {
        _decimals = 18;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function changeDecimals(uint8 newDecimals) public onlyOwner {
        _decimals = newDecimals;
    }
}
