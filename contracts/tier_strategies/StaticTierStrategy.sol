// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../access/ImmutableOwner.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/ITierStrategy.sol";

contract StaticTierStrategy is ImmutableOwner, ITierStrategy {
    uint256 public quorum;
    uint256 public proposalThreshold;
    uint256 public timeLockDuration;

    constructor(address _owner) ImmutableOwner(_owner) {}

    function setParameters(
        uint256 _quorum,
        uint256 _proposalThreshold,
        uint256 _timeLockDuration
    ) external onlyOwner {
        quorum = _quorum;
        proposalThreshold = _proposalThreshold;
        timeLockDuration = _timeLockDuration;
    }

    function getTier(
        bytes calldata
    ) external view returns (DataTypes.Tier memory) {
        if (quorum == 0 && proposalThreshold == 0 && timeLockDuration == 0) {
            revert("static tier has not been initialized");
        }
        return
            DataTypes.Tier({
                quorum: quorum,
                proposalThreshold: proposalThreshold,
                timeLockDuration: timeLockDuration
            });
    }
}
