// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "../../libraries/Errors.sol";

contract ImmutableOwner {
    address public immutable owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Errors.NotAuthorized(msg.sender, owner);
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }
}
