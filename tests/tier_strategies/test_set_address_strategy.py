from eth_utils import function_signature_to_4byte_selector as fn_selector
from eth_abi import encode
from tests.conftest import Tier


def test_set_address_strategy(admin, SetKeyStrategy):
    strict_tier = Tier(
        quorum=5e17,
        vote_threshold=2e17,
        proposal_threshold=2e17,
        time_lock_duration=20,
        proposal_length=20,
        action_level=10,
    )

    less_strict_tier = Tier(
        quorum=2e17,
        vote_threshold=2e17,
        proposal_threshold=2e17,
        time_lock_duration=20,
        proposal_length=20,
        action_level=10,
    )

    tier_strategy = admin.deploy(SetKeyStrategy, admin, strict_tier)
    cd = fn_selector("setAddress(bytes32,address)") + encode(
        ["bytes32", "address"], [b"foo", admin.address]
    )

    tier = tier_strategy.getTier(cd)
    assert tier == strict_tier

    key = encode(["bytes32"], [b"foo"])
    tier_strategy.setValue(key, less_strict_tier)

    tier = tier_strategy.getTier(cd)
    assert tier == less_strict_tier


def test_set_address_strategy_set_default_tier(admin, SetKeyStrategy):
    default_tier = Tier(
        quorum=5e17,
        vote_threshold=2e17,
        proposal_threshold=2e17,
        time_lock_duration=20,
        proposal_length=20,
        action_level=10,
    )

    tier_strategy = admin.deploy(SetKeyStrategy, admin, default_tier)
    cd = fn_selector("setAddress(bytes32,address)") + encode(
        ["bytes32", "address"], [b"foo", admin.address]
    )

    tier = tier_strategy.getTier(cd)
    assert tier == default_tier

    new_default_tier = Tier(
        quorum=2e17,
        vote_threshold=2e17,
        proposal_threshold=2e17,
        time_lock_duration=20,
        proposal_length=20,
        action_level=10,
    )
    tier_strategy.setDefaultTier(new_default_tier)

    tier = tier_strategy.getTier(cd)
    assert tier == new_default_tier
