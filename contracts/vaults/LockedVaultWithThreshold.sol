// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./LockedVault.sol";
import "./VaultWithThreshold.sol";

contract LockedVaultWithThreshold is LockedVault, VaultWithThreshold {
    constructor(
        address _owner,
        address _underlying,
        address _rewardsToken,
        uint256 _threshold
    ) LockedVault(_owner, _underlying, _rewardsToken) {
        threshold = _threshold;
    }
}
