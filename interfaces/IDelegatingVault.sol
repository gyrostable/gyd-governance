// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

interface IDelegatingVault {
    function delegateVote(address _delegate, uint256 _amount) external;

    function undelegateVote(address _delegate, uint256 _amount) external;

    function changeDelegate(
        address _oldDelegate,
        address _newDelegate,
        uint256 _amount
    ) external;

    event VotesDelegated(address delegator, address delegate, uint amount);
    event VotesUndelegated(address delegator, address delegate, uint amount);
}