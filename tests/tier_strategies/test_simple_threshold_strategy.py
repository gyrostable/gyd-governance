import pytest
from eth_utils import function_signature_to_4byte_selector as fn_selector
from eth_abi import encode
from brownie import (
    reverts,
    ZERO_ADDRESS,
    SetRelativeMaxEpsilonStrategy,
    SetStablecoinMaxDeviationStrategy,
    SetVaultMaxDeviationStrategy,
    RegisterVaultStrategy,
)
from tests.conftest import Tier


@pytest.mark.parametrize(
    "strategy_class,encode_fn",
    [
        (
            SetRelativeMaxEpsilonStrategy,
            lambda x: encode(
                ["bytes4", "uint256"],
                [fn_selector("setRelativeMaxEpsilon(uint256)"), int(x)],
            ),
        ),
        (
            SetStablecoinMaxDeviationStrategy,
            lambda x: encode(
                ["bytes4", "uint256"],
                [fn_selector("setStablecoinMaxDeviation(uint256)"), int(x)],
            ),
        ),
        (
            SetVaultMaxDeviationStrategy,
            lambda x: encode(
                ["bytes4", "uint256"],
                [fn_selector("setVaultMaxDeviation(uint256)"), int(x)],
            ),
        ),
        (
            RegisterVaultStrategy,
            lambda x: encode(
                ["bytes4", "address", "uint256", "uint256", "uint256"],
                [
                    fn_selector("registerVault(address,uint256,uint256,uint256)"),
                    ZERO_ADDRESS,
                    int(x),
                    0,
                    0,
                ],
            ),
        ),
    ],
)
def test_simple_threshold_strategy(
    admin, under_tier, over_tier, strategy_class, encode_fn
):
    tier_strategy = admin.deploy(strategy_class, under_tier, over_tier, 3e18)

    cd = encode_fn(2e18)
    got_params = tier_strategy.getTier(cd)
    assert got_params == under_tier

    cd = encode_fn(4e18)
    got_params = tier_strategy.getTier(cd)
    assert got_params == over_tier
