// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../interfaces/IVault.sol";
import "../interfaces/ILockingVault.sol";
import "../libraries/DataTypes.sol";
import "../libraries/Delegations.sol";
import "./access/ImmutableOwner.sol";

contract LPVault is IVault, ILockingVault, ImmutableOwner {
    using EnumerableSet for EnumerableSet.UintSet;
    using Delegations for Delegations.Delegations;

    IERC20 internal lpToken;
    uint256 internal withdrawalWaitDuration;

    // Balances tracks the number of shares locked up that can be used for voting.
    // i.e. shares queued for withdrawal are not accounted here.
    mapping(address => uint256) internal balances;

    Delegations.Delegations internal delegations;

    // Mapping of a user's address to their pending withdrawal ids.
    mapping(address => EnumerableSet.UintSet) internal userPendingWithdrawalIds;

    mapping(uint256 => DataTypes.PendingWithdrawal) internal pendingWithdrawals;

    uint256 internal nextWithdrawalId;

    // Total supply of shares locked in the vault, regardless of whether they
    // are queued for withdrawal or not.
    uint256 public totalSupply;

    constructor(
        address _owner,
        address _lpToken,
        uint256 _withdrawalWaitDuration
    ) ImmutableOwner(_owner) {
        lpToken = IERC20(_lpToken);
        withdrawalWaitDuration = _withdrawalWaitDuration;
    }

    function setWithdrawalWaitDuration(uint256 _duration) external onlyOwner {
        withdrawalWaitDuration = _duration;
    }

    function deposit(uint256 _amount, address _delegate) external {
        require(_delegate != address(0), "no delegation to 0");
        require(_amount > 0, "cannot deposit zero _amount");

        lpToken.transferFrom(msg.sender, address(this), _amount);
        balances[msg.sender] += _amount;
        if (_delegate != address(0) && _delegate != msg.sender) {
            delegations.delegateVote(
                msg.sender,
                _delegate,
                _amount,
                balances[msg.sender]
            );
        }
        totalSupply += _amount;

        emit Deposit(msg.sender, _delegate, _amount);
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
            balances[msg.sender]
        );
    }

    function initiateWithdrawal(
        uint256 _amount,
        address _delegate
    ) external returns (uint256) {
        require(_amount >= 0, "invalid withdrawal amount");

        require(balances[msg.sender] >= _amount, "not enough to undelegate");
        balances[msg.sender] -= _amount;
        if (_delegate != address(0) && _delegate != msg.sender) {
            delegations.undelegateVote(msg.sender, _delegate, _amount);
        }

        DataTypes.PendingWithdrawal memory withdrawal = DataTypes
            .PendingWithdrawal({
                id: nextWithdrawalId,
                withdrawableAt: block.timestamp + withdrawalWaitDuration,
                amount: _amount,
                to: msg.sender,
                delegate: _delegate
            });
        pendingWithdrawals[withdrawal.id] = withdrawal;
        userPendingWithdrawalIds[msg.sender].add(withdrawal.id);
        nextWithdrawalId++;

        emit WithdrawalQueued(
            withdrawal.id,
            withdrawal.to,
            withdrawal.delegate,
            withdrawal.withdrawableAt,
            withdrawal.amount
        );

        return withdrawal.id;
    }

    function withdraw(uint256 withdrawalId) external {
        DataTypes.PendingWithdrawal memory pending = pendingWithdrawals[
            withdrawalId
        ];
        require(pending.to == msg.sender, "matching withdrawal does not exist");
        require(
            pending.withdrawableAt > 0 && pending.amount > 0,
            "matching withdrawal does not exist"
        );
        require(
            pending.withdrawableAt <= block.timestamp,
            "no valid pending withdrawal"
        );

        lpToken.transfer(pending.to, pending.amount);

        totalSupply -= pending.amount;
        delete pendingWithdrawals[withdrawalId];
        userPendingWithdrawalIds[pending.to].remove(withdrawalId);

        emit WithdrawalCompleted(pending.to, pending.amount);
    }

    function getRawVotingPower(address _user) external view returns (uint256) {
        return
            uint256(
                int256(balances[_user]) + delegations.netDelegatedVotes(_user)
            );
    }

    function getTotalRawVotingPower() external view returns (uint256) {
        return totalSupply;
    }

    function listPendingWithdrawals(
        address _user
    ) external view returns (DataTypes.PendingWithdrawal[] memory) {
        EnumerableSet.UintSet storage ids = userPendingWithdrawalIds[_user];
        DataTypes.PendingWithdrawal[]
            memory pending = new DataTypes.PendingWithdrawal[](ids.length());
        for (uint256 i = 0; i < ids.length(); i++) {
            pending[i] = pendingWithdrawals[ids.at(i)];
        }
        return pending;
    }
}
