// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

interface ILockingVault {
    function deposit(uint256 _amount) external;

    function deposit(uint256 _amount, address _delegate) external;

    event Deposit(address from, address delegate, uint256 amount);

    function initiateWithdrawal(
        uint256 _amount,
        address _delegate
    ) external returns (uint256);

    function withdraw(uint256 withdrawalId) external;

    event WithdrawalQueued(
        uint256 id,
        address to,
        address delegate,
        uint256 withdrawalAt,
        uint256 amount
    );
    event WithdrawalCompleted(address to, uint256 amount);
}
