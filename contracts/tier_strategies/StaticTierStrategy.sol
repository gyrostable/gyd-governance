// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../access/ImmutableOwner.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/ITierStrategy.sol";

contract StaticTierStrategy is ImmutableOwner, ITierStrategy {
    DataTypes.Tier public tier;

    constructor(
        address _owner,
        DataTypes.Tier memory _tier
    ) ImmutableOwner(_owner) {
        tier = _tier;
    }

    function getTier(
        bytes calldata
    ) external view returns (DataTypes.Tier memory) {
        return tier;
    }
}
