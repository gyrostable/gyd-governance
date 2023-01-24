// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./access/GovernanceOnly.sol";
import "../interfaces/IWrappedERC20WithEMA.sol";
import "../libraries/ScaledMath.sol";
import "../libraries/LogExpMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WrappedERC20WithEMA is IWrappedERC20WithEMA, ERC20, GovernanceOnly {
    using ScaledMath for uint256;
    using LogExpMath for uint256;

    IERC20 internal underlying;

    struct UintValue {
        uint256 blockNb;
        uint256 value;
    }

    UintValue public previousWrappedPctOfSupply;
    UintValue public expMovingAverage;

    uint256 internal windowWidth;

    constructor(
        address governance,
        address _underlying,
        uint256 _windowWidth
    ) ERC20("WrappedGYD", "wGYD") GovernanceOnly(governance) {
        underlying = IERC20(_underlying);
        windowWidth = _windowWidth;

        uint256 wrappedPct = wrappedPctOfSupply();
        expMovingAverage.value = wrappedPct;
        previousWrappedPctOfSupply.value = wrappedPct;

        expMovingAverage.blockNb = block.number;
        previousWrappedPctOfSupply.blockNb = block.number;
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

    function wrappedPctOfSupply() public view returns (uint256) {
        return (totalSupply() * ScaledMath.ONE) / underlying.totalSupply();
    }

    event Debug(
        uint256 deltaBlockNb,
        int256 exponent,
        uint256 windowWidth,
        uint256 ema
    );

    function _updateEMA() internal {
        if (previousWrappedPctOfSupply.blockNb < block.number) {
            uint256 deltaBlockNb = (previousWrappedPctOfSupply.blockNb -
                expMovingAverage.blockNb) * ScaledMath.ONE;
            int256 exponent = -int256(deltaBlockNb.divDown(windowWidth));
            emit Debug(
                deltaBlockNb,
                exponent,
                windowWidth,
                expMovingAverage.value
            );
            expMovingAverage.value += uint256(
                ((int256(ScaledMath.ONE) - LogExpMath.exp(exponent)) *
                    int256(
                        previousWrappedPctOfSupply.value -
                            expMovingAverage.value
                    )) / int256(ScaledMath.ONE)
            );
            expMovingAverage.blockNb = previousWrappedPctOfSupply.blockNb;
        }
        previousWrappedPctOfSupply.value = wrappedPctOfSupply();
        previousWrappedPctOfSupply.blockNb = block.number;
    }

    function updateEMA() external {
        _updateEMA();
    }

    function wrappedPctEMA() public view returns (uint256) {
        return uint256(expMovingAverage.value);
    }
}
