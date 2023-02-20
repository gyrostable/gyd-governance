// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../LiquidityMining.sol";
import "./ERC20Mintable.sol";

contract SampleLiquidityMining is LiquidityMining {
    ERC20Mintable public rewardToken;
    IERC20 public depositToken;

    constructor(IERC20 _depositToken) LiquidityMining() {
        depositToken = _depositToken;
        rewardToken = new ERC20Mintable();
        _lastCheckpointTime = block.timestamp;
    }

    function deposit(uint256 amount) external {
        depositToken.transferFrom(msg.sender, address(this), amount);
        _stake(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        _unstake(msg.sender, amount);
        depositToken.transfer(msg.sender, amount);
    }

    /// @dev 1M tokens per year
    function rewardsEmissionRate() public pure override returns (uint256) {
        return uint256(1_000_000e18) / 365 days;
    }

    function _mintRewards(
        address account,
        uint256 amount
    ) internal override returns (uint256) {
        rewardToken.mint(account, amount);
        return amount;
    }
}
