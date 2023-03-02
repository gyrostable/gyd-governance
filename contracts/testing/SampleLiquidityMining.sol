// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../LiquidityMining.sol";

contract SampleLiquidityMining is LiquidityMining {
    IERC20 public depositToken;

    constructor(IERC20 _depositToken, IERC20 _rewardsToken) LiquidityMining(_rewardsToken) {
        depositToken = _depositToken;
    }

    function deposit(uint256 amount) external {
        depositToken.transferFrom(msg.sender, address(this), amount);
        _stake(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        _unstake(msg.sender, amount);
        depositToken.transfer(msg.sender, amount);
    }

    function startMining(address rewardsFrom, uint256 amount, uint256 endTime) external {
        _startMining(rewardsFrom, amount, endTime);
    }
    function stopMining(address reimbursementTo) external {
        _stopMining(reimbursementTo);
    }
}
