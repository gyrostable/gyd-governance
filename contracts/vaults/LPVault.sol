// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/IVault.sol";
import "../../interfaces/ILockingVault.sol";
import "../../interfaces/IDelegatingVault.sol";
import "../../libraries/DataTypes.sol";
import "../../libraries/VotingPowerHistory.sol";
import "../access/ImmutableOwner.sol";
import "../LiquidityMining.sol";

contract LPVault is
    IVault,
    ILockingVault,
    IDelegatingVault,
    ImmutableOwner,
    LiquidityMining
{
    using EnumerableSet for EnumerableSet.UintSet;
    using VotingPowerHistory for VotingPowerHistory.History;

    IERC20 internal lpToken;
    uint256 internal withdrawalWaitDuration;

    VotingPowerHistory.History internal history;

    // Mapping of a user's address to their pending withdrawal ids.
    mapping(address => EnumerableSet.UintSet) internal userPendingWithdrawalIds;

    mapping(uint256 => DataTypes.PendingWithdrawal) internal pendingWithdrawals;

    uint256 internal nextWithdrawalId;

    // Total supply of shares locked in the vault that are not queued for withdrawal
    uint256 public totalSupply;

    constructor(
        address _owner,
        address _lpToken,
        address _rewardsToken,
        uint256 _withdrawalWaitDuration
    ) ImmutableOwner(_owner) LiquidityMining(_rewardsToken) {
        lpToken = IERC20(_lpToken);
        withdrawalWaitDuration = _withdrawalWaitDuration;
    }

    function startMining(address rewardsFrom, uint256 amount, uint256 endTime) external override onlyOwner {
        _startMining(rewardsFrom, amount, endTime);
    }
    function stopMining(address reimbursementTo) external override onlyOwner {
        _stopMining(reimbursementTo);
    }

    function setWithdrawalWaitDuration(uint256 _duration) external onlyOwner {
        withdrawalWaitDuration = _duration;
    }

    function deposit(uint256 _amount, address _delegate) external {
        require(_delegate != address(0), "no delegation to 0");
        require(_amount > 0, "cannot deposit zero _amount");

        lpToken.transferFrom(msg.sender, address(this), _amount);
        VotingPowerHistory.Record memory current = history.currentRecord(
            msg.sender
        );
        history.updateVotingPower(
            msg.sender,
            current.baseVotingPower + _amount,
            current.multiplier,
            current.netDelegatedVotes
        );
        if (_delegate != address(0) && _delegate != msg.sender) {
            history.delegateVote(msg.sender, _delegate, _amount);
        }
        totalSupply += _amount;
        _stake(msg.sender, _amount);

        emit Deposit(msg.sender, _delegate, _amount);
    }

    function delegateVote(address _delegate, uint256 _amount) external {
        history.delegateVote(msg.sender, _delegate, _amount);
    }

    function undelegateVote(address _delegate, uint256 _amount) external {
        history.undelegateVote(msg.sender, _delegate, _amount);
    }

    function changeDelegate(
        address _oldDelegate,
        address _newDelegate,
        uint256 _amount
    ) external {
        history.undelegateVote(msg.sender, _oldDelegate, _amount);
        history.delegateVote(msg.sender, _newDelegate, _amount);
    }

    function initiateWithdrawal(
        uint256 _amount,
        address _delegate
    ) external returns (uint256) {
        require(_amount >= 0, "invalid withdrawal amount");

        VotingPowerHistory.Record memory currentVotingPower = history
            .currentRecord(msg.sender);
        require(
            currentVotingPower.baseVotingPower >= _amount,
            "not enough to undelegate"
        );
        history.updateVotingPower(
            msg.sender,
            currentVotingPower.baseVotingPower - _amount,
            currentVotingPower.multiplier,
            currentVotingPower.netDelegatedVotes
        );
        if (_delegate != address(0) && _delegate != msg.sender) {
            history.undelegateVote(msg.sender, _delegate, _amount);
        }
        totalSupply -= _amount;
        _unstake(msg.sender, _amount);

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

        delete pendingWithdrawals[withdrawalId];
        userPendingWithdrawalIds[pending.to].remove(withdrawalId);

        emit WithdrawalCompleted(pending.to, pending.amount);
    }

    function getRawVotingPower(address _user) external view returns (uint256) {
        return history.getVotingPower(_user, block.timestamp);
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

    function rewardsEmissionRate() public view override returns (uint256) {
        // TODO: decide on actual value
        return uint256(100_000e18) / 365 days;
    }

    function _mintRewards(
        address beneficiary,
        uint256 amount
    ) internal override returns (uint256) {
        // TODO: decide on how to handle rewards
        return amount;
    }
}
