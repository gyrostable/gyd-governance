// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../interfaces/IVault.sol";
import "../interfaces/IDelegator.sol";
import "./access/ImmutableOwner.sol";
import "../libraries/DataTypes.sol";
import "../libraries/TotalVotingPower.sol";

abstract contract NFTVault is IVault, IDelegator, ImmutableOwner {
    using TotalVotingPower for DataTypes.BaseVotingPower;
    // Stores the number of votes delegated by a user and to whom.
    mapping(address => mapping(address => uint256)) internal delegations;

    // Stores the sum of votes delegated by a user to others.
    mapping(address => uint256) internal delegatedAmounts;

    // All of the delegated votes a user has received.
    mapping(address => uint256) internal userToDelegatedVotes;

    // A user's own voting power, excluding delegations either to or from the user.
    // This caches voting power and stores voting power mutations.
    mapping(address => DataTypes.BaseVotingPower) internal ownVotingPowers;

    uint256 internal sumVotingPowers;

    constructor(address _owner) ImmutableOwner(_owner) {}

    function delegateVote(address _delegate, uint256 _amount) external {
        // TODO: Delegate fractional amounts
        uint256 remaining = ownVotingPowers[msg.sender].total() -
            delegatedAmounts[msg.sender];
        require(remaining >= _amount, "insufficient balance to delegate");

        userToDelegatedVotes[_delegate] += _amount;
        delegatedAmounts[msg.sender] += _amount;
        delegations[msg.sender][_delegate] += _amount;

        emit VotesDelegated(msg.sender, _delegate, _amount);
    }

    function undelegateVote(address _delegate, uint256 _amount) external {
        require(
            delegations[msg.sender][_delegate] >= _amount,
            "user has not delegated enough to _delegate"
        );

        delegations[msg.sender][_delegate] -= _amount;
        delegatedAmounts[msg.sender] -= _amount;
        userToDelegatedVotes[_delegate] -= _amount;

        emit VotesUndelegated(msg.sender, _delegate, _amount);
    }

    function getRawVotingPower(address user) external view returns (uint256) {
        return
            ownVotingPowers[user].total() -
            delegatedAmounts[user] +
            userToDelegatedVotes[user];
    }

    function getTotalRawVotingPower() external view returns (uint256) {
        return sumVotingPowers;
    }

    function updateMultiplier(
        address[] calldata users,
        uint128 _multiplier
    ) external onlyOwner {
        require(_multiplier >= 1, "multiplier cannot be less than 1");
        require(_multiplier <= 20, "multiplier cannot be more than 20");
        for (uint i = 0; i < users.length; i++) {
            DataTypes.BaseVotingPower storage oldVotingPower = ownVotingPowers[
                users[i]
            ];
            require(
                oldVotingPower.base >= 1,
                "all users must have at least 1 NFT"
            );
            require(
                oldVotingPower.multiplier < _multiplier,
                "cannot decrease voting power"
            );

            uint256 oldTotal = oldVotingPower.total();
            oldVotingPower.multiplier = _multiplier;
            sumVotingPowers += (oldVotingPower.total() - oldTotal);
        }
    }
}
