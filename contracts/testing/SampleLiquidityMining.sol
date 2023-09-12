// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.17;

import "../LiquidityMining.sol";

contract SampleLiquidityMining is LiquidityMining {
    IERC20 public depositToken;

    constructor(
        address _depositToken,
        address _rewardsToken,
        address _daoTreasury
    ) LiquidityMining(_rewardsToken, _daoTreasury) {
        depositToken = IERC20(_depositToken);
    }

    function deposit(uint256 amount) external {
        depositToken.transferFrom(msg.sender, address(this), amount);
        _stake(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        _unstake(msg.sender, amount);
        depositToken.transfer(msg.sender, amount);
    }

    function startMining(
        address rewardsFrom,
        uint256 amount,
        uint256 endTime
    ) external override {
        _startMining(rewardsFrom, amount, endTime);
    }

    function stopMining() external override {
        _stopMining();
    }
}
