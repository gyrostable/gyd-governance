import pytest
from typing import NamedTuple
from brownie import ActionTierConfig, StaticTierStrategy, reverts
from eth_utils import keccak, function_signature_to_4byte_selector
from tests.conftest import Tier


@pytest.fixture
def tier_config(admin):
    return admin.deploy(ActionTierConfig, admin)


def test_reverts_if_no_strategy_defined(admin, tier_config):
    with reverts("strategy not found"):
        tier_config.getTier(admin.address, "")


def test_set_and_get_strategy(admin, token, tier_config, static_tier_strategy):
    selector = function_signature_to_4byte_selector("totalSupply()")
    tier_config.setStrategy(token, selector, static_tier_strategy)

    assert tier_config.getStrategy(token, selector) == static_tier_strategy


def test_get_tier(admin, token, tier_config, static_tier_strategy):
    params = Tier(
        quorum=1e17,  # 0.1
        proposal_threshold=2e17,  # 0.2
        time_lock_duration=10,  # 10s
        proposal_length=10,  # 10s
    )
    selector = function_signature_to_4byte_selector("totalSupply()")

    tier_config.setStrategy(token, selector, static_tier_strategy)

    # `totalSupply` takes no arguments.
    calldata = selector
    tier = tier_config.getTier(token, calldata)
    assert tier == params
