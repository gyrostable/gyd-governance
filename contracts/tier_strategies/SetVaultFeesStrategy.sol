// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../access/ImmutableOwner.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/ITierStrategy.sol";

contract SetVaultFeesStrategy is ImmutableOwner, ITierStrategy {
    DataTypes.Tier private underThresholdTier;
    DataTypes.Tier private overThresholdTier;
    uint256 private threshold;

    constructor(
        address _owner,
        uint256 _threshold,
        DataTypes.Tier memory underTier,
        DataTypes.Tier memory overTier
    ) ImmutableOwner(_owner) {
        threshold = _threshold;
        underThresholdTier = underTier;
        overThresholdTier = overTier;
    }

    function setParameters(
        uint256 _threshold,
        DataTypes.Tier calldata underTier,
        DataTypes.Tier calldata overTier
    ) external onlyOwner {
        threshold = _threshold;
        underThresholdTier = underTier;
        overThresholdTier = overTier;
    }

    function getTier(
        bytes calldata _calldata
    ) external view returns (DataTypes.Tier memory) {
        // The function signature of the payload we're trying to decode is:
        // SetVaultFees(address vault, uint256 mintFee, uint256 redeemFee)
        (, , uint256 mintFee, uint256 redeemFee) = abi.decode(
            _calldata,
            (bytes4, address, uint256, uint256)
        );
        if (mintFee > threshold || redeemFee > threshold) {
            return overThresholdTier;
        } else {
            return underThresholdTier;
        }
    }
}
