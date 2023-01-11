// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../access/ImmutableOwner.sol";

import "../../interfaces/IVault.sol";

contract FriendlyDAOVault is IVault, ImmutableOwner {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap internal _daoVotingPower;
    uint256 internal _totalRawVotingPower;

    constructor(address _owner) ImmutableOwner(_owner) {}

    function updateDAOAndTotalWeight(
        address dao,
        uint256 votingPower,
        uint256 totalVotingPower
    ) external onlyOwner {
        _daoVotingPower.set(dao, votingPower);
        _totalRawVotingPower = totalVotingPower;

        uint256 actualTotalPower;
        uint256 daosCount = _daoVotingPower.length();
        for (uint256 i; i < daosCount; i++) {
            (, uint256 currentPower) = _daoVotingPower.at(i);
            actualTotalPower += currentPower;
        }
        if (actualTotalPower > totalVotingPower)
            revert Errors.InvalidVotingPowerUpdate(
                actualTotalPower,
                totalVotingPower
            );
    }

    function getRawVotingPower(
        address account
    ) external view returns (uint256) {
        return _daoVotingPower.get(account);
    }

    function getTotalRawVotingPower() external view returns (uint256) {
        return _totalRawVotingPower;
    }
}
