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
    mapping(address => Delegation) internal voteDelegation;

    // All of the delegated votes a user has received.
    mapping(address => uint256) internal delegations;

    uint internal totalSupply;

    constructor(address tokenAddress) {
        nftContract = IERC721Enumerable(tokenAddress);
        totalSupply = nftContract.totalSupply();
    }

    function delegateVote(address _delegate, uint256 _amount) external {
        uint256 remaining = _remainingBalance(msg.sender);
        require(remaining >= _amount, "insufficient balance to delegate");

        delegations[_delegate] += _amount;
        voteDelegation[msg.sender] = Delegation(_amount, _delegate);

        emit VotesDelegated(msg.sender, _delegate, _amount);
    }

    function _remainingBalance(address user) internal view returns (uint256) {
        uint256 balance = nftContract.balanceOf(user);
        uint256 delegatedBalance = voteDelegation[user].amount;
        return balance - delegatedBalance;
    }

    function undelegateVote(address _delegate, uint256 _amount) external {
        require(
            voteDelegation[msg.sender].amount > 0,
            "user has not delegated"
        );
        require(
            voteDelegation[msg.sender].delegate == _delegate,
            "user has not delegated to _delegate"
        );

        require(
            voteDelegation[msg.sender].amount == _amount,
            "partial undelegations not allowed"
        );

        delete voteDelegation[msg.sender];
        delegations[_delegate] -= _amount;

        emit VotesUndelegated(msg.sender, _delegate, _amount);
    }

    function rawVotingPower(address user) external view returns (uint256) {
        return _remainingBalance(user) + delegations[user];
    }

    function totalRawVotingPower() external view returns (uint256) {
        return totalSupply;
    }
}
