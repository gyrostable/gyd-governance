pragma solidity ^0.8.17;

import "../access/ImmutableOwner.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/ITierStrategy.sol";
import "./SimpleThresholdStrategy.sol";

contract RegisterVaultStrategy is SimpleThresholdStrategy, ITierStrategy {
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
        // RegisterVault(
        //   address _addressOfVault,
        //   uint256 initialWeight,
        //   uint256 shortflowMemory,
        //   uint256 shortflowThreshold)
        (, , uint256 initialWeight, , ) = abi.decode(
            _calldata,
            (bytes4, address, uint256, uint256, uint256)
        );
        return _getThresholdTier(initialWeight);
    }
}
