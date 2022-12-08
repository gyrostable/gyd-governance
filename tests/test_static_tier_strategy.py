from eth_utils import function_signature_to_4byte_selector
from brownie import reverts
from tests.conftest import Tier


def test_returns_params_if_initialized(static_tier_strategy):
    params = Tier(
        quorum=1e17, proposal_threshold=2e17, time_lock_duration=10, proposal_length=10
    )
    selector = function_signature_to_4byte_selector("totalSupply()")
    got_params = static_tier_strategy.getTier(selector)
    assert got_params == params
