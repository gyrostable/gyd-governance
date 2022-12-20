// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../interfaces/ITierer.sol";
import "../../libraries/DataTypes.sol";

contract MockTierer is ITierer {
    DataTypes.Tier private tier;

    constructor(DataTypes.Tier memory _tier) {
        tier = _tier;
    }

    function getTier(
        address,
        bytes calldata
    ) external view returns (DataTypes.Tier memory) {
        return tier;
    }
}
