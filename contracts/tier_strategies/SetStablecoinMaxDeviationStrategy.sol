pragma solidity ^0.8.17;

import "../access/ImmutableOwner.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/ITierStrategy.sol";
import "./SimpleThresholdStrategy.sol";

contract SetStablecoinMaxDeviationStrategy is
    SimpleThresholdStrategy,
    ITierStrategy
{
    constructor(
        DataTypes.Tier memory _underThresholdTier,
        DataTypes.Tier memory _overThresholdTier,
        uint256 _threshold
    )
        SimpleThresholdStrategy(
            _underThresholdTier,
            _overThresholdTier,
            _threshold
        )
    {}

    function getTier(
        bytes calldata _calldata
    ) external view returns (DataTypes.Tier memory) {
        // SetStablecoinMaxDeviationStrategy(uint256)
        (, uint256 stablecoinMaxDeviation) = abi.decode(
            _calldata,
            (bytes4, uint256)
        );
        return _getThresholdTier(stablecoinMaxDeviation);
    }
}
