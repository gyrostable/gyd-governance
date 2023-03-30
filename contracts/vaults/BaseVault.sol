// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "../../interfaces/IVault.sol";
import "../../libraries/Errors.sol";

abstract contract BaseVault is IVault {
    /// @dev 0 is a valid value for the total voting power
    /// Therefore, the first 31 bytes represent the voting power
    /// and the last byte represents whether the snapshot exists or not
    mapping(uint256 => uint256) internal _snapshots;

    address public immutable votingPowerAggregator;

    modifier onlyVotingPowerAggregator() {
        if (msg.sender != votingPowerAggregator)
            revert Errors.NotAuthorized(msg.sender, votingPowerAggregator);
        _;
    }

    constructor(address _votingPowerAggregator) {
        votingPowerAggregator = _votingPowerAggregator;
    }

    function snapshotTotalRawVotingPower() external onlyVotingPowerAggregator {
        uint256 currentVotingPower = getTotalRawVotingPower();
        _snapshots[block.timestamp] = (currentVotingPower << 1) | 1;
    }

    function getRawVotingPower(
        address account
    ) external view returns (uint256) {
        return getRawVotingPower(account, block.timestamp);
    }

    function getTotalRawVotingPower(
        uint256 timestamp
    ) external view returns (uint256) {
        if (timestamp == block.timestamp) return getTotalRawVotingPower();
        uint256 snapshot = _snapshots[timestamp];
        require((snapshot & 1) == 1, "snapshot does not exist");
        return snapshot >> 1;
    }

    function getTotalRawVotingPower() public view virtual returns (uint256);

    function getRawVotingPower(
        address account,
        uint256 timestamp
    ) public view virtual returns (uint256);
}
