// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../interfaces/IVotingVault.sol";
import "../interfaces/IDelegator.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract NFTVault is IVotingVault, IDelegator {
    IERC721Enumerable internal nftContract;

    struct Delegation {
        uint256 amount;
        address delegate;
    }

    // Stores whether or not a user's NFT has been delegated.
    // We can assume the NFT is non-transferrable and that a user will
    // have at most one NFT, and consequently at most one delegation of votes.
    mapping(address => Delegation) internal delegations;

    // All of the delegated votes a user has received.
    mapping(address => uint256) internal userToDelegatedVotes;

    // A user's own voting power, excluding delegations either to or from the user.
    // This caches voting power and stores voting power mutations.
    mapping(address => uint256) internal ownVotingPowers;

    uint internal totalSupply;

    constructor(address tokenAddress) {
        nftContract = IERC721Enumerable(tokenAddress);
        totalSupply = nftContract.totalSupply();
    }

    // The user's base voting power, without taking into account
    // votes delegated from the user to others, and vice versa.
    // If the user has the NFT, cache this into the contract.
    function _ownVotingPower(address user) internal returns (uint256) {
        (uint256 balance, bool cached) = _readOwnVotingPower(user);
        if (!cached && balance > 0) {
            ownVotingPowers[user] = balance;
        }
        return balance;
    }

    function _readOwnVotingPower(
        address user
    ) internal view returns (uint256, bool) {
        uint256 balance = ownVotingPowers[user];
        if (balance > 0) {
            return (balance, true);
        }

        return (nftContract.balanceOf(user), false);
    }

    function delegateVote(address _delegate, uint256 _amount) external {
        // TODO: Delegate fractional amounts
        uint256 remaining = _ownVotingPower(msg.sender) -
            delegations[msg.sender].amount;
        require(remaining >= _amount, "insufficient balance to delegate");

        userToDelegatedVotes[_delegate] += _amount;
        delegations[msg.sender] = Delegation(_amount, _delegate);

        emit VotesDelegated(msg.sender, _delegate, _amount);
    }

    function undelegateVote(address _delegate, uint256 _amount) external {
        require(delegations[msg.sender].amount > 0, "user has not delegated");
        require(
            delegations[msg.sender].delegate == _delegate,
            "user has not delegated to _delegate"
        );

        require(
            delegations[msg.sender].amount == _amount,
            "partial undelegations not allowed"
        );

        delete delegations[msg.sender];
        userToDelegatedVotes[_delegate] -= _amount;

        emit VotesUndelegated(msg.sender, _delegate, _amount);
    }

    function rawVotingPower(address user) external view returns (uint256) {
        (uint256 ownVotingPower, ) = _readOwnVotingPower(user);
        return
            ownVotingPower -
            delegations[user].amount +
            userToDelegatedVotes[user];
    }

    function totalRawVotingPower() external view returns (uint256) {
        return totalSupply;
    }

    function updateRawVotingPower(
        address[] calldata users,
        uint256 _amount
    ) external {
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
            totalSupply += (_amount - oldVotingPower);
        }
    }
}
