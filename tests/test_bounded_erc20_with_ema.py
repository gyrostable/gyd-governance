from brownie import chain

from tests.conftest import INITIAL_BALANCE


def test_deposit(admin, bounded_erc20, token):
    token.approve(bounded_erc20.address, 100, {"from": admin})
    bounded_erc20.deposit(20, {"from": admin})

    assert bounded_erc20.totalSupply() == 20

    assert bounded_erc20.balanceOf(admin) == 20

    assert token.balanceOf(bounded_erc20) == 20
    assert token.balanceOf(admin) == INITIAL_BALANCE - 20


def test_withdraw(admin, bounded_erc20, token):
    token.approve(bounded_erc20.address, 100, {"from": admin})
    bounded_erc20.deposit(20, {"from": admin})

    bounded_erc20.withdraw(20, {"from": admin})
    assert bounded_erc20.totalSupply() == 0
    assert token.balanceOf(bounded_erc20) == 0
    assert token.balanceOf(admin) == INITIAL_BALANCE


def test_ema(admin, bounded_erc20, token):
    # EMA at start = 0, since there are no bounded tokens
    assert bounded_erc20.boundedPctEMA() == 0

    token.approve(bounded_erc20.address, 100, {"from": admin})
    bounded_erc20.deposit(20, {"from": admin})
    chain.mine()

    # EMA after deposit is still at 0, since the EMA excludes the current block
    # average when it is calculated
    assert bounded_erc20.boundedPctEMA() == 0

    previousEMA = 12e16
    for i in range(20):
        chain.mine()
        bounded_erc20.updateEMA({"from": admin})
        ema = bounded_erc20.boundedPctEMA()
        assert previousEMA < ema <= 20e16
        previousEMA = ema

    chain.mine(blocks=100)
    bounded_erc20.updateEMA({"from": admin})
    ema = bounded_erc20.boundedPctEMA()
    assert previousEMA < ema <= 20e16
    chain.mine()
    bounded_erc20.updateEMA({"from": admin})
    ema = bounded_erc20.boundedPctEMA()
    assert previousEMA < ema <= 20e16
