// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IDelegator {
    function delegateVote(address delegate, uint256 amount) external;

    function undelegateVote(address delegate, uint256 amount) external;

    event VotesDelegated(address delegator, address delegate, uint amount);
    event VotesUndelegated(address delegator, address delegate, uint amount);
}
