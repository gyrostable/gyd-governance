// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "./BaseThresholdStrategy.sol";
import "../../libraries/DataTypes.sol";

contract SimpleThresholdStrategy is BaseThresholdStrategy {
    uint256 public threshold;
    uint256 public paramPosition;

    constructor(
        DataTypes.Tier memory _underThresholdTier,
        DataTypes.Tier memory _overThresholdTier,
        uint256 _threshold,
        uint256 _paramPosition
    ) BaseThresholdStrategy(_underThresholdTier, _overThresholdTier) {
        threshold = _threshold;
        paramPosition = _paramPosition;
    }

    function _isOverThreshold(
        bytes calldata data
    ) internal view virtual override returns (bool) {
        // skip selector and get the param at the specified position
        uint256 startIndex = 4 + paramPosition * 32;
        bytes calldata paramBytes = data[startIndex:startIndex + 32];
        uint256 param = uint256(bytes32(paramBytes));

        return param >= threshold;
    }
}
