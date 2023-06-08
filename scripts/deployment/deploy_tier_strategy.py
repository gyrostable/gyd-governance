from brownie import StaticTierStrategy, GovernanceManagerProxy  # type: ignore
from scripts.utils import get_deployer, make_params
from tests.conftest import Tier
from tests.support.utils import scale


def upgradeability():
    get_deployer().deploy(
        StaticTierStrategy,
        GovernanceManagerProxy[0],
        Tier(
            quorum=int(scale("0.4")),
            proposal_threshold=int(scale("0.1")),
            vote_threshold=int(scale("0.6")),
            time_lock_duration=10 * 86400,
            proposal_length=10 * 86400,
            action_level=20,
        ),
        **make_params()
    )


def static_medium_impact():
    get_deployer().deploy(
        StaticTierStrategy,
        GovernanceManagerProxy[0],
        Tier(
            quorum=int(scale("0.2")),
            proposal_threshold=int(scale("0.02")),
            vote_threshold=int(scale("0.5")),
            time_lock_duration=3 * 86400,
            proposal_length=7 * 86400,
            action_level=15,
        ),
        **make_params()
    )
