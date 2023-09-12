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

import "./access/GovernanceOnly.sol";
import "../interfaces/IBoundedERC20WithEMA.sol";
import "../libraries/ScaledMath.sol";
import "../libraries/LogExpMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BoundedERC20WithEMA is IBoundedERC20WithEMA, ERC20, GovernanceOnly {
    using ScaledMath for uint256;
    using LogExpMath for uint256;

    event WindowWidthUpdated(uint256 windowWidth);

    IERC20 public underlying;

    struct UintValue {
        uint256 blockNb;
        uint256 value;
    }

    UintValue public previousBoundedPctOfSupply;
    UintValue public expMovingAverage;

    uint256 public windowWidth;

    constructor(
        address governance,
        address _underlying,
        uint256 _windowWidth
    ) ERC20("BoundedGYD", "bGYD") GovernanceOnly(governance) {
        require(
            _windowWidth >= 0.01e18,
            "window width must be scaled to 18 decimals"
        );
        underlying = IERC20(_underlying);
        windowWidth = _windowWidth;

        uint256 boundedPct = boundedPctOfSupply();
        expMovingAverage.value = boundedPct;
        previousBoundedPctOfSupply.value = boundedPct;

        expMovingAverage.blockNb = block.number;
        previousBoundedPctOfSupply.blockNb = block.number;

        emit WindowWidthUpdated(windowWidth);
    }

    event Deposit(address indexed src, uint256 amount);

    function deposit(uint256 _amount) public {
        underlying.transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
        emit Deposit(msg.sender, _amount);
        _updateEMA();
    }

    event Withdraw(address indexed dst, uint256 amount);

    function withdraw(uint256 _amount) public {
        _burn(msg.sender, _amount);
        underlying.transfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
        _updateEMA();
    }

    function boundedPctOfSupply() public view returns (uint256) {
        return totalSupply().divDown(underlying.totalSupply());
    }

    function _updateEMA() internal {
        if (previousBoundedPctOfSupply.blockNb < block.number) {
            uint256 multiplier = ScaledMath.ONE;
            uint256 deltaBlockNb = (previousBoundedPctOfSupply.blockNb -
                expMovingAverage.blockNb) * multiplier;
            int256 exponent = -int256(deltaBlockNb.divDown(windowWidth));
            if (exponent > LogExpMath.MIN_NATURAL_EXPONENT) {
                int256 discount = LogExpMath.exp(exponent);
                multiplier -= uint256(discount);
            }

            if (previousBoundedPctOfSupply.value > expMovingAverage.value) {
                expMovingAverage.value += (previousBoundedPctOfSupply.value -
                    expMovingAverage.value).mulDown(multiplier);
            } else {
                expMovingAverage.value -= (expMovingAverage.value -
                    previousBoundedPctOfSupply.value).mulDown(multiplier);
            }

            expMovingAverage.blockNb = previousBoundedPctOfSupply.blockNb;
        }
        previousBoundedPctOfSupply.value = boundedPctOfSupply();
        previousBoundedPctOfSupply.blockNb = block.number;
    }

    function updateEMA() external {
        _updateEMA();
    }

    function setWindowWidth(uint256 _windowWidth) external governanceOnly {
        require(
            _windowWidth >= 0.01e18,
            "window width must be scaled to 18 decimals"
        );
        windowWidth = _windowWidth;
        emit WindowWidthUpdated(windowWidth);
    }

    function boundedPctEMA() public view returns (uint256) {
        return uint256(expMovingAverage.value);
    }
}
