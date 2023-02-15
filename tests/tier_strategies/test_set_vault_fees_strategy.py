import pytest
from eth_utils import function_signature_to_4byte_selector
from eth_abi import encode
from brownie import reverts, SetVaultFeesStrategy
from tests.conftest import Tier


@pytest.fixture
def set_vault_fees_strategy(admin, under_tier, over_tier):
    return admin.deploy(SetVaultFeesStrategy, admin, 3e18, under_tier, over_tier)


def test_returns_over_tier_if_over(set_vault_fees_strategy, admin, over_tier):
    cd = function_signature_to_4byte_selector(
        "setVaultFees(address,uint256,uint256)"
    ) + encode(
        ["address", "uint256", "uint256"],
        [
            admin.address,
            int(5e18),
            0,
        ],
    )
    got_params = set_vault_fees_strategy.getTier(cd)
    assert got_params == over_tier


def test_returns_under_tier_if_under(set_vault_fees_strategy, admin, under_tier):
    cd = function_signature_to_4byte_selector(
        "setVaultFees(address,uint256,uint256)"
    ) + encode(
        ["address", "uint256", "uint256"],
        [
            admin.address,
            int(2e18),
            0,
        ],
    )
    got_params = set_vault_fees_strategy.getTier(cd)
    assert got_params == under_tier


def test_set_parameters(set_vault_fees_strategy, admin, under_tier, over_tier):
    cd = function_signature_to_4byte_selector(
        "setVaultFees(address,uint256,uint256)"
    ) + encode(
        ["address", "uint256", "uint256"],
        [
            admin.address,
            int(2e18),
            0,
        ],
    )
    got_params = set_vault_fees_strategy.getTier(cd)
    assert got_params == under_tier

    set_vault_fees_strategy.setParameters(1e18, under_tier, over_tier)

    got_params = set_vault_fees_strategy.getTier(cd)
    assert got_params == over_tier
