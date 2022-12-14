// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

contract MockProxy {
    address public _upgradeTo;

    function upgradeTo(address to) external {
        _upgradeTo = to;
    }
}
