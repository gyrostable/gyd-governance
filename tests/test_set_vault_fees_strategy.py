import pytest
from eth_utils import function_signature_to_4byte_selector
from eth_abi import encode
from brownie import reverts, SetVaultFeesStrategy


@pytest.fixture
def set_vault_fees_strategy(admin):
    return admin.deploy(SetVaultFeesStrategy, admin)


def test_reverts_if_not_initialized_correctly(set_vault_fees_strategy, admin):
    cd = encode(
        ["bytes4", "address", "uint256", "uint256"],
        [
            function_signature_to_4byte_selector(
                "setVaultFees(address,uint256,uint256"
            ),
            admin.address,
            0,
            0,
        ],
    )
    with reverts("tier strategy not initialized"):
        set_vault_fees_strategy.getTier(cd)


def test_returns_over_tier_if_over(set_vault_fees_strategy, admin):
    over_params = (500, 20, 20)
    set_vault_fees_strategy.setParameters(3, (100, 20, 20), over_params)
    cd = encode(
        ["bytes4", "address", "uint256", "uint256"],
        [
            function_signature_to_4byte_selector(
                "setVaultFees(address,uint256,uint256"
            ),
            admin.address,
            5,
            0,
        ],
    )
    got_params = set_vault_fees_strategy.getTier(cd)
    assert got_params == over_params


def test_returns_under_tier_if_under(set_vault_fees_strategy, admin):
    under_params = (100, 20, 20)
    set_vault_fees_strategy.setParameters(3, under_params, (500, 20, 20))
    cd = encode(
        ["bytes4", "address", "uint256", "uint256"],
        [
            function_signature_to_4byte_selector(
                "setVaultFees(address,uint256,uint256"
            ),
            admin.address,
            2,
            0,
        ],
    )
    got_params = set_vault_fees_strategy.getTier(cd)
    assert got_params == under_params
