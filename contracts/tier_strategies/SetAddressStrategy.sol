// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../access/GovernanceOnly.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/ITierStrategy.sol";

contract SetAddressStrategy is ITierStrategy, GovernanceOnly {
    mapping(bytes32 => MapValue) keysToTiers;
    DataTypes.Tier public defaultTier;

    struct MapValue {
        DataTypes.Tier tier;
        bool present;
    }

    constructor(
        address _governance,
        DataTypes.Tier memory _defaultTier
    ) GovernanceOnly(_governance) {
        defaultTier = _defaultTier;
    }

    function setDefaultTier(
        DataTypes.Tier memory _defaultTier
    ) external governanceOnly {
        defaultTier = _defaultTier;
    }

    function setValue(
        bytes32 key,
        DataTypes.Tier memory tier
    ) external governanceOnly {
        keysToTiers[key] = MapValue({present: true, tier: tier});
    }

    function getTier(
        bytes calldata _calldata
    ) external view returns (DataTypes.Tier memory) {
        (bytes32 key, ) = abi.decode(_calldata[4:], (bytes32, address));

        MapValue memory mapValue = keysToTiers[key];
        if (!mapValue.present) {
            return defaultTier;
        }

        return mapValue.tier;
    }
}
