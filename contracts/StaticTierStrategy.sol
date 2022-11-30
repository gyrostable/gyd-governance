// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./access/ImmutableOwner.sol";
import "../libraries/DataTypes.sol";
import "../interfaces/ITierStrategy.sol";

contract StaticTierStrategy is ImmutableOwner, ITierStrategy {
  uint256 public quorum;
  uint256 public proposalThreshold;
  uint256 public timeLockDuration;

  constructor(address _owner) ImmutableOwner(_owner) {}

  function setProposalThreshold(uint256 _proposalThreshold) external onlyOwner {
    proposalThreshold = _proposalThreshold;
  }

  function setQuorum(uint256 _quorum) external onlyOwner {
    quorum = _quorum;
  }

  function setTimeLockDuration(uint256 _timeLockDuration) external onlyOwner {
    timeLockDuration = _timeLockDuration;
  }

  function getTier(
      bytes calldata
  ) external view returns (DataTypes.Tier memory) {
    return DataTypes.Tier({
      quorum: quorum,
      proposalThreshold: proposalThreshold,
      timeLockDuration: timeLockDuration
    });
  }
}
