import pytest
from eth_utils import function_signature_to_4byte_selector as fn_selector
from eth_abi import encode
from brownie import reverts, ZERO_ADDRESS, SetSystemParamsStrategy
from tests.conftest import Tier


def test_set_system_params_strategy(admin, under_tier, over_tier):
    tier_strategy = admin.deploy(
        SetSystemParamsStrategy, under_tier, over_tier, 3e18, 3e18
    )

    cd = encode(
        ["bytes4", "uint64", "uint64", "uint64", "uint64"],
        [
            fn_selector("setSystemParams((uint64,uint64,uint64,uint64))"),
            0,
            0,
            int(2e18),
            int(4e18),
        ],
    )

    got_params = tier_strategy.getTier(cd)
    assert got_params == under_tier

    cd = encode(
        ["bytes4", "uint64", "uint64", "uint64", "uint64"],
        [
            fn_selector("setSystemParams((uint64,uint64,uint64,uint64))"),
            0,
            0,
            int(4e18),
            int(2e18),
        ],
    )

    got_params = tier_strategy.getTier(cd)
    assert got_params == under_tier

    cd = encode(
        ["bytes4", "uint64", "uint64", "uint64", "uint64"],
        [
            fn_selector("setSystemParams((uint64,uint64,uint64,uint64))"),
            0,
            0,
            int(2e18),
            int(2e18),
        ],
    )

    got_params = tier_strategy.getTier(cd)
    assert got_params == under_tier

    cd = encode(
        ["bytes4", "uint64", "uint64", "uint64", "uint64"],
        [
            fn_selector("setSystemParams((uint64,uint64,uint64,uint64))"),
            0,
            0,
            int(4e18),
            int(4e18),
        ],
    )

    got_params = tier_strategy.getTier(cd)
    assert got_params == over_tier
