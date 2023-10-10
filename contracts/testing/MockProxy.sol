// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

contract MockProxy {
    address public _upgradeTo;

    function upgradeTo(address to) external {
        _upgradeTo = to;
    }
}
