// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../access/ImmutableOwner.sol";
import "../../libraries/VotingPowerHistory.sol";

import "./BaseDelegatingVault.sol";
import "../../interfaces/IDelegatingVault.sol";

contract FriendlyDAOVault is BaseDelegatingVault, ImmutableOwner {
    using EnumerableSet for EnumerableSet.AddressSet;
    using VotingPowerHistory for VotingPowerHistory.History;

    EnumerableSet.AddressSet internal _daos;
    uint256 internal _totalRawVotingPower;

    constructor(address _owner) ImmutableOwner(_owner) {}

    function updateDAOAndTotalWeight(
        address dao,
        uint256 votingPower,
        uint256 totalVotingPower
    ) external onlyOwner {
        _daos.add(dao);

        VotingPowerHistory.Record memory current = history.currentRecord(dao);
        history.updateVotingPower(
            dao,
            votingPower,
            ScaledMath.ONE,
            current.netDelegatedVotes
        );

        _totalRawVotingPower = totalVotingPower;

        uint256 actualTotalPower;
        uint256 daosCount = _daos.length();
        for (uint256 i; i < daosCount; i++) {
            uint256 currentPower = history.getVotingPower(dao, block.timestamp);
            actualTotalPower += currentPower;
        }

        if (actualTotalPower > totalVotingPower)
            revert Errors.InvalidVotingPowerUpdate(
                actualTotalPower,
                totalVotingPower
            );
    }

    function getRawVotingPower(
        address account,
        uint256 timestamp
    ) public view override returns (uint256) {
        return history.getVotingPower(account, timestamp);
    }

    function getTotalRawVotingPower() public view override returns (uint256) {
        return _totalRawVotingPower;
    }
}
