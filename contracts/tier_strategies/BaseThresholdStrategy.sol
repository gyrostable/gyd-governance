// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../libraries/DataTypes.sol";
import "../../interfaces/ITierStrategy.sol";

abstract contract BaseThresholdStrategy is ITierStrategy {
    DataTypes.Tier public underThresholdTier;
    DataTypes.Tier public overThresholdTier;

    constructor(
        DataTypes.Tier memory _underThresholdTier,
        DataTypes.Tier memory _overThresholdTier
    ) {
        underThresholdTier = _underThresholdTier;
        overThresholdTier = _overThresholdTier;
    }

    function getTier(
        bytes calldata data
    ) external view returns (DataTypes.Tier memory) {
        if (_isOverThreshold(data)) {
            return overThresholdTier;
        } else {
            return underThresholdTier;
        }
    }

    function _isOverThreshold(
        bytes calldata data
    ) internal view virtual returns (bool);
}
