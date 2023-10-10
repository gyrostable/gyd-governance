// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./BaseThresholdStrategy.sol";
import "../access/GovernanceOnly.sol";
import "../../libraries/DataTypes.sol";

contract SimpleThresholdStrategy is BaseThresholdStrategy, GovernanceOnly {
    uint256 public threshold;
    uint256 public paramPosition;

    constructor(
        DataTypes.Tier memory _underThresholdTier,
        DataTypes.Tier memory _overThresholdTier,
        uint256 _threshold,
        uint256 _paramPosition,
        address _governance
    )
        BaseThresholdStrategy(_underThresholdTier, _overThresholdTier)
        GovernanceOnly(_governance)
    {
        threshold = _threshold;
        paramPosition = _paramPosition;
    }

    function setParameters(
        DataTypes.Tier memory _underThresholdTier,
        DataTypes.Tier memory _overThresholdTier,
        uint256 _threshold,
        uint256 _paramPosition
    ) external governanceOnly {
        underThresholdTier = _underThresholdTier;
        overThresholdTier = _overThresholdTier;
        paramPosition = _paramPosition;
        threshold = _threshold;
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
