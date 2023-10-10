// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../access/GovernanceOnly.sol";
import "../../libraries/DataTypes.sol";
import "./BaseThresholdStrategy.sol";

contract SetSystemParamsStrategy is BaseThresholdStrategy, GovernanceOnly {
    uint64 public thetaBarThreshold;
    uint64 public outflowMemoryThreshold;

    constructor(
        address _governance,
        DataTypes.Tier memory _underThresholdTier,
        DataTypes.Tier memory _overThresholdTier,
        uint64 _thetaBarThreshold,
        uint64 _outflowMemoryThreshold
    )
        BaseThresholdStrategy(_underThresholdTier, _overThresholdTier)
        GovernanceOnly(_governance)
    {
        thetaBarThreshold = _thetaBarThreshold;
        outflowMemoryThreshold = _outflowMemoryThreshold;
    }

    function setParameters(
        DataTypes.Tier memory _underThresholdTier,
        DataTypes.Tier memory _overThresholdTier,
        uint64 _thetaBarThreshold,
        uint64 _outflowMemoryThreshold
    ) external governanceOnly {
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

    function _isOverThreshold(
        bytes calldata data
    ) internal view virtual override returns (bool) {
        Params memory params = abi.decode(data[4:], (Params));
        return
            params.thetaBar > thetaBarThreshold &&
            params.outflowMemory > outflowMemoryThreshold;
    }
}
