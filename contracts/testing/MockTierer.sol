// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../interfaces/ITierer.sol";
import "../../libraries/DataTypes.sol";

contract MockTierer is ITierer {
    DataTypes.Tier private tier;
    OverrideTier[] private overrides;

    struct OverrideTier {
        address addr;
        DataTypes.Tier tier;
    }

    constructor(DataTypes.Tier memory _tier) {
        tier = _tier;
    }

    function setOverride(address _addr, DataTypes.Tier memory _tier) public {
        overrides.push(OverrideTier({addr: _addr, tier: _tier}));
    }

    function getTier(
        address _addr,
        bytes calldata
    ) external view returns (DataTypes.Tier memory) {
        for (uint256 i = 0; i < overrides.length; i++) {
            if (overrides[i].addr == _addr) {
                return overrides[i].tier;
            }
        }

        return tier;
    }
}
