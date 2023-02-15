// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../access/GovernanceOnly.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/ITierStrategy.sol";

contract StaticTierStrategy is ITierStrategy, GovernanceOnly {
    DataTypes.Tier public tier;

    constructor(
        address _governance,
        DataTypes.Tier memory _tier
    ) GovernanceOnly(_governance) {
        tier = _tier;
    }

    function setTier(DataTypes.Tier memory _tier) external governanceOnly {
        tier = _tier;
    }

    function getTier(
        bytes calldata
    ) external view returns (DataTypes.Tier memory) {
        return tier;
    }
}
