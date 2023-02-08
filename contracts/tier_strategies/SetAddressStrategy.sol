// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../access/ImmutableOwner.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/ITierStrategy.sol";

contract SetAddressStrategy is ITierStrategy, ImmutableOwner {
    mapping(bytes32 => MapValue) keysToTiers;
    DataTypes.Tier public defaultTier;

    struct MapValue {
        DataTypes.Tier tier;
        bool present;
    }

    constructor(
        address _owner,
        DataTypes.Tier memory _defaultTier
    ) ImmutableOwner(_owner) {
        defaultTier = _defaultTier;
    }

    function setValue(
        bytes32 key,
        DataTypes.Tier memory tier
    ) external onlyOwner {
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
