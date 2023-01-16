import pytest
from eth_utils import function_signature_to_4byte_selector
from eth_abi import encode
from brownie import reverts, SetVaultFeesStrategy
from tests.conftest import Tier


@pytest.fixture
def set_vault_fees_strategy(admin):
    underTier = Tier(
        quorum=2e17,
        vote_threshold=2e17,
        proposal_threshold=2e17,
        time_lock_duration=20,
        proposal_length=20,
        action_level=10,
    )
    overTier = Tier(
        quorum=5e17,
        vote_threshold=2e17,
        proposal_threshold=2e17,
        time_lock_duration=20,
        proposal_length=20,
        action_level=10,
    )
    return admin.deploy(SetVaultFeesStrategy, admin, 3e18, underTier, overTier)


def test_returns_over_tier_if_over(set_vault_fees_strategy, admin):
    over_params = Tier(
        quorum=5e17,
        vote_threshold=2e17,
        proposal_threshold=2e17,
        time_lock_duration=20,
        proposal_length=20,
        action_level=10,
    )
    cd = encode(
        ["bytes4", "address", "uint256", "uint256"],
        [
            function_signature_to_4byte_selector(
                "setVaultFees(address,uint256,uint256)"
            ),
            admin.address,
            int(5e18),
            0,
        ],
    )
    got_params = set_vault_fees_strategy.getTier(cd)
    assert got_params == over_params


def test_returns_under_tier_if_under(set_vault_fees_strategy, admin):
    under_params = Tier(
        quorum=2e17,
        vote_threshold=2e17,
        proposal_threshold=2e17,
        time_lock_duration=20,
        proposal_length=20,
        action_level=10,
    )
    cd = encode(
        ["bytes4", "address", "uint256", "uint256"],
        [
            function_signature_to_4byte_selector(
                "setVaultFees(address,uint256,uint256)"
            ),
            admin.address,
            int(2e18),
            0,
        ],
    )
    got_params = set_vault_fees_strategy.getTier(cd)
    assert got_params == under_params
