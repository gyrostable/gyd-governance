// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "../../interfaces/IVault.sol";
import "../../libraries/Errors.sol";

abstract contract BaseVault is IVault {
    function getRawVotingPower(
        address account
    ) external view returns (uint256) {
        return getRawVotingPower(account, block.timestamp);
    }

    function getRawVotingPower(
        address account,
        uint256 timestamp
    ) public view virtual returns (uint256);
}
