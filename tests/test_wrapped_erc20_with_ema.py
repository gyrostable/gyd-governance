from tests.conftest import INITIAL_BALANCE
from brownie import chain


def test_deposit(admin, wrapped_erc20, token):
    token.approve(wrapped_erc20.address, 100, {"from": admin})
    wrapped_erc20.deposit(20, {"from": admin})

    assert wrapped_erc20.totalSupply() == 20

    assert wrapped_erc20.balanceOf(admin) == 20

    assert token.balanceOf(wrapped_erc20) == 20
    assert token.balanceOf(admin) == INITIAL_BALANCE - 20


def test_withdraw(admin, wrapped_erc20, token):
    token.approve(wrapped_erc20.address, 100, {"from": admin})
    wrapped_erc20.deposit(20, {"from": admin})

    wrapped_erc20.withdraw(20, {"from": admin})
    assert wrapped_erc20.totalSupply() == 0
    assert token.balanceOf(wrapped_erc20) == 0
    assert token.balanceOf(admin) == INITIAL_BALANCE


def test_ema(admin, wrapped_erc20, token):
    # EMA at start = 0, since there are no wrapped tokens
    assert wrapped_erc20.wrappedPctEMA() == 0

    token.approve(wrapped_erc20.address, 100, {"from": admin})
    wrapped_erc20.deposit(20, {"from": admin})
    chain.mine()

    # EMA after deposit is still at 0, since the EMA excludes the current block
    # average when it is calculated
    assert wrapped_erc20.wrappedPctEMA() == 0

    previousEMA = 12e16
    for i in range(20):
        chain.mine()
        wrapped_erc20.updateEMA({"from": admin})
        ema = wrapped_erc20.wrappedPctEMA()
        assert previousEMA < ema <= 20e16
        previousEMA = ema

    chain.mine(blocks=100)
    wrapped_erc20.updateEMA({"from": admin})
    ema = wrapped_erc20.wrappedPctEMA()
    assert previousEMA < ema <= 20e16
    chain.mine()
    wrapped_erc20.updateEMA({"from": admin})
    ema = wrapped_erc20.wrappedPctEMA()
    assert previousEMA < ema <= 20e16
