// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./DataTypes.sol";
import "./ScaledMath.sol";

library BaseVotingPower {
    using ScaledMath for uint256;

    function total(
        DataTypes.BaseVotingPower memory p
    ) internal pure returns (uint256) {
        return
            uint256(p.base).mulDown(
                uint256(p.multiplier == 0 ? ScaledMath.ONE : p.multiplier)
            );
    }

    function initialize(DataTypes.BaseVotingPower storage p) internal {
        if (p.multiplier == 0) {
            p.multiplier = uint128(ScaledMath.ONE);
        }
    }
}
