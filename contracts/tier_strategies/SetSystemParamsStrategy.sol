// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../access/ImmutableOwner.sol";
import "../../libraries/DataTypes.sol";
import "./BaseThresholdStrategy.sol";

contract SetSystemParamsStrategy is BaseThresholdStrategy {
    uint64 private thetaBarThreshold;
    uint64 private outflowMemoryThreshold;

    constructor(
        DataTypes.Tier memory _underThresholdTier,
        DataTypes.Tier memory _overThresholdTier,
        uint64 _thetaBarThreshold,
        uint64 _outflowMemoryThreshold
    ) BaseThresholdStrategy(_underThresholdTier, _overThresholdTier) {
        thetaBarThreshold = _thetaBarThreshold;
        outflowMemoryThreshold = _outflowMemoryThreshold;
    }

    struct Params {
        uint64 alphaBar;
        uint64 xuBar;
        uint64 thetaBar;
        uint64 outflowMemory;
    }

    function _isOverThreshold(
        bytes calldata data
    ) internal view virtual override returns (bool) {
        Params memory params = abi.decode(data[4:], (Params));
        return
            params.thetaBar > thetaBarThreshold &&
            params.outflowMemory > outflowMemoryThreshold;
    }
}
