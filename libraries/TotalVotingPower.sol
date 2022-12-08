// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./DataTypes.sol";

library TotalVotingPower {
    function total(
        DataTypes.BaseVotingPower memory p
    ) internal pure returns (uint256) {
        return p.base * (p.multiplier == 0 ? 1 : p.multiplier);
    }
}
