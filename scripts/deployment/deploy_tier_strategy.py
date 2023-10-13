from brownie import StaticTierStrategy, GovernanceManagerProxy  # type: ignore
from scripts.utils import get_deployer, make_params
from tests.conftest import Tier
from tests.support.utils import scale


LOW_TIER = Tier(
    quorum=int(scale("0.01")),
    proposal_threshold=int(scale("0.025")),
    vote_threshold=int(scale("0.51")),
    time_lock_duration=86400,
    proposal_length=7 * 86400,
    action_level=10,
)


MEDIUM_TIER = Tier(
    quorum=int(scale("0.02")),
    proposal_threshold=int(scale("0.025")),
    vote_threshold=int(scale("0.51")),
    time_lock_duration=2 * 86400,
    proposal_length=7 * 86400,
    action_level=20,
)

HIGH_TIER = Tier(
    quorum=int(scale("0.05")),
    proposal_threshold=int(scale("0.025")),
    vote_threshold=int(scale("0.67")),
    time_lock_duration=7 * 86400,
    proposal_length=7 * 86400,
    action_level=30,
)

CORE_TIER = Tier(
    quorum=int(scale("0.1")),
    proposal_threshold=int(scale("0.025")),
    vote_threshold=int(scale("0.75")),
    time_lock_duration=7 * 86400,
    proposal_length=7 * 86400,
    action_level=40,
)

HIGH_TREASURY_TIER = Tier(
    quorum=int(scale("0.05")),
    proposal_threshold=int(scale("0.025")),
    vote_threshold=int(scale("0.67")),
    time_lock_duration=2 * 86400,
    proposal_length=14 * 86400,
    action_level=25,
)

UPGRADEABILITY_TIER = Tier(
    quorum=int(scale("0.5")),
    proposal_threshold=int(scale("0.025")),
    vote_threshold=int(scale("0.75")),
    time_lock_duration=14 * 86400,
    proposal_length=14 * 86400,
    action_level=100,
)


def upgradeability():
    get_deployer().deploy(
        StaticTierStrategy,
        GovernanceManagerProxy[0],
        UPGRADEABILITY_TIER,
        **make_params(),
    )


def static_low_tier():
    get_deployer().deploy(
        StaticTierStrategy,
        GovernanceManagerProxy[0],
        LOW_TIER,
        **make_params(),
    )


def static_medium_tier():
    get_deployer().deploy(
        StaticTierStrategy,
        GovernanceManagerProxy[0],
        MEDIUM_TIER,
        **make_params(),
    )


def static_high_tier():
    get_deployer().deploy(
        StaticTierStrategy,
        GovernanceManagerProxy[0],
        HIGH_TIER,
        **make_params(),
    )


def static_core_tier():
    get_deployer().deploy(
        StaticTierStrategy,
        GovernanceManagerProxy[0],
        CORE_TIER,
        **make_params(),
    )


def static_high_treasury():
    get_deployer().deploy(
        StaticTierStrategy,
        GovernanceManagerProxy[0],
        HIGH_TREASURY_TIER,
        **make_params(),
    )
