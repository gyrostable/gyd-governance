// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../interfaces/IVault.sol";
import "../interfaces/IDelegator.sol";
import "./access/ImmutableOwner.sol";

abstract contract NFTVault is IVault, IDelegator, ImmutableOwner {
    // Stores the number of votes delegated by a user and to whom.
    mapping(address => mapping(address => uint256)) internal delegations;

    // Stores the sum of votes delegated by a user to others.
    mapping(address => uint256) internal delegatedAmounts;

    // All of the delegated votes a user has received.
    mapping(address => uint256) internal userToDelegatedVotes;

    // A user's own voting power, excluding delegations either to or from the user.
    // This caches voting power and stores voting power mutations.
    mapping(address => uint256) internal ownVotingPowers;

    uint internal sumVotingPowers;

    constructor(address _owner) ImmutableOwner(_owner) {}

    // The user's base voting power, without taking into account
    // votes delegated from the user to others, and vice versa.
    // If the user has the NFT, cache this into the contract.
    function _ownVotingPower(address user) internal virtual returns (uint256);

    function _readOwnVotingPower(
        address user
    ) internal view virtual returns (uint256, bool);

    function delegateVote(address _delegate, uint256 _amount) external {
        // TODO: Delegate fractional amounts
        uint256 remaining = _ownVotingPower(msg.sender) -
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

        if (delegations[msg.sender][_delegate] == _amount) {
            delete delegations[msg.sender][_delegate];
        } else {
            delegations[msg.sender][_delegate] -= _amount;
        }

        delegatedAmounts[msg.sender] -= _amount;
        userToDelegatedVotes[_delegate] -= _amount;

        emit VotesUndelegated(msg.sender, _delegate, _amount);
    }

    function getRawVotingPower(address user) external view returns (uint256) {
        (uint256 ownVotingPower, ) = _readOwnVotingPower(user);

        return
            ownVotingPower -
            delegatedAmounts[user] +
            userToDelegatedVotes[user];
    }

    function getTotalRawVotingPower() external view returns (uint256) {
        return sumVotingPowers;
    }

    function updateRawVotingPower(
        address[] calldata users,
        uint256 _amount
    ) external onlyOwner {
        uint256[] memory oldVotingPowers = new uint256[](users.length);

        require(_amount >= 1, "voting power cannot be less than 1");
        require(_amount <= 20, "voting power cannot be more than 20");
        for (uint i = 0; i < users.length; i++) {
            uint256 ownVotingPower = _ownVotingPower(users[i]);
            oldVotingPowers[i] = ownVotingPower;
            require(ownVotingPower >= 1, "all users must have at least 1 NFT");
            require(ownVotingPower < _amount, "cannot decrease voting power");
        }

        for (uint i = 0; i < users.length; i++) {
            uint256 oldVotingPower = oldVotingPowers[i];
            ownVotingPowers[users[i]] = _amount;
            sumVotingPowers += (_amount - oldVotingPower);
        }
    }
}
