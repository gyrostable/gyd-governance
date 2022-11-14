from brownie import accounts


def test_account_balance():
    assert accounts[0].balance() >= 0
