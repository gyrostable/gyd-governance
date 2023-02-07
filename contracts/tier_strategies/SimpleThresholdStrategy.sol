pragma solidity ^0.8.17;

import "../../libraries/DataTypes.sol";

contract SimpleThresholdStrategy {
    DataTypes.Tier private underThresholdTier;
    DataTypes.Tier private overThresholdTier;
    uint256 private threshold;

    constructor(
        DataTypes.Tier memory _underThresholdTier,
        DataTypes.Tier memory _overThresholdTier,
        uint256 _threshold
    ) {
        underThresholdTier = _underThresholdTier;
        overThresholdTier = _overThresholdTier;
        threshold = _threshold;
    }

    function _getThresholdTier(
        uint256 value
    ) internal view returns (DataTypes.Tier memory) {
        if (value >= threshold) {
            return overThresholdTier;
        } else {
            return underThresholdTier;
        }
    }
}
