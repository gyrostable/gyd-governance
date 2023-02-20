import pytest
from eth_utils import function_signature_to_4byte_selector as fn_selector
from eth_abi import encode
from brownie import (
    reverts,
    ZERO_ADDRESS,
    SimpleThresholdStrategy,
)
from tests.conftest import Tier


@pytest.mark.parametrize(
    "param_index,encode_fn",
    [
        (
            0,
            lambda x: fn_selector("setRelativeMaxEpsilon(uint256)")
            + encode(["uint256"], [int(x)]),
        ),
        (
            0,
            lambda x: fn_selector("setStablecoinMaxDeviation(uint256)")
            + encode(["uint256"], [int(x)]),
        ),
        (
            0,
            lambda x: fn_selector("setVaultMaxDeviation(uint256)")
            + encode(["uint256"], [int(x)]),
        ),
        (
            1,
            lambda x: fn_selector("registerVault(address,uint256,uint256,uint256)")
            + encode(
                ["address", "uint256", "uint256", "uint256"],
                [ZERO_ADDRESS, int(x), 0, 0],
            ),
        ),
    ],
)
def test_simple_threshold_strategy(
    admin, under_tier, over_tier, param_index, encode_fn
):
    tier_strategy = admin.deploy(
        SimpleThresholdStrategy, under_tier, over_tier, 3e18, param_index, admin
    )

    cd = encode_fn(2e18)
    got_params = tier_strategy.getTier(cd)
    assert got_params == under_tier

    cd = encode_fn(4e18)
    got_params = tier_strategy.getTier(cd)
    assert got_params == over_tier


def test_simple_threshold_strategy_set_parameters(admin, under_tier, over_tier):
    tier_strategy = admin.deploy(
        SimpleThresholdStrategy, under_tier, over_tier, 3e18, 0, admin
    )
    cd = fn_selector("setRelativeMaxEpsilon(uint256)") + encode(
        ["uint256"], [int(2e18)]
    )

    got_params = tier_strategy.getTier(cd)
    assert got_params == under_tier

    tier_strategy.setParameters(under_tier, over_tier, 1e18, 0)

    got_params = tier_strategy.getTier(cd)
    assert got_params == over_tier
