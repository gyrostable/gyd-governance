pragma solidity ^0.8.17;

import "../access/ImmutableOwner.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/ITierStrategy.sol";

contract SetSystemParamsStrategy is ITierStrategy {
    DataTypes.Tier private underThresholdTier;
    DataTypes.Tier private overThresholdTier;
    uint64 private thetaBarThreshold;
    uint64 private outflowMemoryThreshold;

    constructor(
        DataTypes.Tier memory _underThresholdTier,
        DataTypes.Tier memory _overThresholdTier,
        uint64 _thetaBarThreshold,
        uint64 _outflowMemoryThreshold
    ) {
        underThresholdTier = _underThresholdTier;
        overThresholdTier = _overThresholdTier;
        thetaBarThreshold = _thetaBarThreshold;
        outflowMemoryThreshold = _outflowMemoryThreshold;
    }

    struct Params {
        uint64 alphaBar;
        uint64 xuBar;
        uint64 thetaBar;
        uint64 outflowMemory;
    }

    function getTier(
        bytes calldata _calldata
    ) external view returns (DataTypes.Tier memory) {
        // SetSystemParams((uint64, uint64, uint64, uint64))
        (, Params memory params) = abi.decode(_calldata, (bytes4, Params));

        if (
            params.thetaBar <= thetaBarThreshold ||
            params.outflowMemory <= outflowMemoryThreshold
        ) {
            return underThresholdTier;
        } else {
            return overThresholdTier;
        }
    }
}
