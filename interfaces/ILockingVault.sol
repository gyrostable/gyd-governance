// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

interface ILockingVault {
    function deposit(uint256 _amount) external payable;

    event Deposit(address from, uint256 amount);

    function initiateWithdrawal(uint256 _amount) external;

    function withdraw() external payable;

    event WithdrawalQueued(address to, uint256 withdrawalAt, uint256 amount);
    event WithdrawalCompleted(address to, uint256 amount);
}
