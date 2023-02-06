// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../access/ImmutableOwner.sol";
import "../../libraries/Delegations.sol";

import "../../interfaces/IVault.sol";
import "../../interfaces/IDelegatingVault.sol";

contract FriendlyDAOVault is IVault, IDelegatingVault, ImmutableOwner {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using Delegations for Delegations.Delegations;

    EnumerableMap.AddressToUintMap internal _daoVotingPower;
    uint256 internal _totalRawVotingPower;

    Delegations.Delegations internal delegations;

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

    function baseTotalFor(address account) internal view returns (uint256) {
        (, uint256 baseTotal) = _daoVotingPower.tryGet(account);
        return baseTotal;
    }

    function delegateVote(address _delegate, uint256 _amount) external {
        delegations.delegateVote(
            msg.sender,
            _delegate,
            _amount,
            baseTotalFor(msg.sender)
        );
    }

    function undelegateVote(address _delegate, uint256 _amount) external {
        delegations.undelegateVote(msg.sender, _delegate, _amount);
    }

    function changeDelegate(
        address _oldDelegate,
        address _newDelegate,
        uint256 _amount
    ) external {
        delegations.undelegateVote(msg.sender, _oldDelegate, _amount);
        delegations.delegateVote(
            msg.sender,
            _newDelegate,
            _amount,
            baseTotalFor(msg.sender)
        );
    }

    function getRawVotingPower(
        address account
    ) external view returns (uint256) {
        return
            uint256(
                int256(baseTotalFor(account)) +
                    delegations.netDelegatedVotes(account)
            );
    }

    function getTotalRawVotingPower() external view returns (uint256) {
        return _totalRawVotingPower;
    }
}
