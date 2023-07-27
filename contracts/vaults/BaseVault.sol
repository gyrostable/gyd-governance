// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "../../interfaces/IVault.sol";

import "../../libraries/Errors.sol";
import "../../libraries/DataTypes.sol";
import "../../libraries/VotingPowerHistory.sol";

abstract contract BaseVault is IVault {
    using VotingPowerHistory for VotingPowerHistory.History;

    VotingPowerHistory.History internal history;

    function getCurrentRecord(
        address account
    ) external view returns (VotingPowerHistory.Record memory) {
        return history.currentRecord(account);
    }

    function getRawVotingPower(
        address account
    ) external view returns (uint256) {
        return getRawVotingPower(account, block.timestamp);
    }

    function getRawVotingPower(
        address account,
        uint256 timestamp
    ) public view virtual returns (uint256);
}
