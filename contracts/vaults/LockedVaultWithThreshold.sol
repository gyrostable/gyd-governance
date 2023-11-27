// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./LockedVault.sol";
import "./VaultWithThreshold.sol";

contract LockedVaultWithThreshold is LockedVault, VaultWithThreshold {
    constructor(
        address _owner,
        address _underlying,
        address _rewardsToken,
        uint256 _threshold,
        address _daoTreasury
    ) LockedVault(_owner, _underlying, _rewardsToken, _daoTreasury) {
        threshold = _threshold;
    }

    function getTotalRawVotingPower()
        public
        view
        virtual
        override
        returns (uint256)
    {
        if (totalSupply < threshold) {
            return threshold;
        }
        return totalSupply;
    }
}
