from eth_utils import function_signature_to_4byte_selector
from brownie import reverts


def test_reverts_if_not_initialized_correctly(static_tier_strategy):
    selector = function_signature_to_4byte_selector("totalSupply()")
    with reverts("static tier has not been initialized"):
        static_tier_strategy.getTier(selector)


def test_returns_params_if_initialized(static_tier_strategy):
    selector = function_signature_to_4byte_selector("totalSupply()")
    params = (100, 20, 10)
    static_tier_strategy.setParameters(*params)

    got_params = static_tier_strategy.getTier(selector)
    assert got_params == params
