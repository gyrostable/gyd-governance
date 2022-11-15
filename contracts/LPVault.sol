// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IVault.sol";
import "../interfaces/ILockingVault.sol";
import "../libraries/DataTypes.sol";
import "./access/ImmutableOwner.sol";

contract LPVault is IVault, ILockingVault, ImmutableOwner {
    IERC20 internal lpToken;
    uint256 internal withdrawalWaitDuration;

    mapping(address => uint256) internal balances;

    mapping(address => DataTypes.PendingWithdrawal) internal pendingWithdrawals;

    uint256 internal totalSupply;

    constructor(
        address _owner,
        address _lpToken,
        uint256 _withdrawalWaitDuration
    ) ImmutableOwner(_owner) {
        lpToken = IERC20(_lpToken);
        withdrawalWaitDuration = _withdrawalWaitDuration;
    }

    function _totalBalance(address _user) internal view returns (uint256) {
        return balances[_user] + pendingWithdrawals[_user].amount;
    }

    function deposit(uint256 _amount) external payable {
        require(_amount > 0, "cannot deposit zero _amount");

        lpToken.transferFrom(msg.sender, address(this), _amount);
        balances[msg.sender] += _amount;
        totalSupply += _amount;

        emit Deposit(msg.sender, _amount);
    }

    function initiateWithdrawal(uint256 _amount) external {
        require(
            _totalBalance(msg.sender) >= _amount,
            "cannot unlock more than balance"
        );

        // Handle the case where a user initiates a withdrawal, and then initiates another one, but without
        // completing the first one.
        // This allows users to "undo" a withdrawal initiation, but complicates the logic somewhat since we must:
        // - determine by how much to change the balances[msg.sender]
        // - overwrite the pending withdrawal amount and reset the withdrawal wait duration.
        uint256 existingAmount = pendingWithdrawals[msg.sender].amount;
        if (existingAmount > _amount) {
            // We're trying to withdraw less than initially, so increase the user's balance by the difference;
            balances[msg.sender] += existingAmount - _amount;
        } else {
            // We're trying to withdraw more than initially, so decrease the user's balance by the difference;
            balances[msg.sender] -= _amount - existingAmount;
        }

        uint256 withdrawableAt = block.timestamp + withdrawalWaitDuration;
        pendingWithdrawals[msg.sender] = DataTypes.PendingWithdrawal({
            withdrawableAt: withdrawableAt,
            amount: _amount
        });

        emit WithdrawalQueued(msg.sender, withdrawableAt, _amount);
    }

    function withdraw() external payable {
        DataTypes.PendingWithdrawal memory pending = pendingWithdrawals[
            msg.sender
        ];
        require(
            pending.withdrawableAt <= block.timestamp,
            "no valid pending withdrawal"
        );

        lpToken.transfer(msg.sender, pending.amount);

        uint256 amount = pending.amount;
        totalSupply -= amount;
        delete pendingWithdrawals[msg.sender];

        emit WithdrawalCompleted(msg.sender, pending.amount);
    }

    function getRawVotingPower(address _user) external view returns (uint256) {
        return balances[_user];
    }

    function getTotalRawVotingPower() external view returns (uint256) {
        return totalSupply;
    }
}
