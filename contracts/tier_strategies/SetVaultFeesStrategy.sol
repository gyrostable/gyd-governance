// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../access/GovernanceOnly.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/ITierStrategy.sol";
import "./BaseThresholdStrategy.sol";

contract SetVaultFeesStrategy is GovernanceOnly, BaseThresholdStrategy {
    uint256 public threshold;

    constructor(
        address _governance,
        uint256 _threshold,
        DataTypes.Tier memory underTier,
        DataTypes.Tier memory overTier
    ) BaseThresholdStrategy(underTier, overTier) GovernanceOnly(_governance) {
        threshold = _threshold;
    }

    function setParameters(
        uint256 _threshold,
        DataTypes.Tier calldata underTier,
        DataTypes.Tier calldata overTier
    ) external governanceOnly {
        threshold = _threshold;
        underThresholdTier = underTier;
        overThresholdTier = overTier;
    }

    function _isOverThreshold(
        bytes calldata _calldata
    ) internal view virtual override returns (bool) {
        // The function signature of the payload we're trying to decode is:
        // SetVaultFees(address vault, uint256 mintFee, uint256 redeemFee)
        (, uint256 mintFee, uint256 redeemFee) = abi.decode(
            _calldata[4:],
            (address, uint256, uint256)
        );
        return mintFee > threshold || redeemFee > threshold;
    }
}
