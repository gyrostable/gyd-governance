from brownie import StaticTierStrategy, GovernanceManagerProxy  # type: ignore
from scripts.utils import get_deployer, make_params
from tests.conftest import Tier
from tests.support.utils import scale


def upgradeability():
    get_deployer().deploy(
        StaticTierStrategy,
        GovernanceManagerProxy[0],
        Tier(
            quorum=int(scale("0.2")),
            proposal_threshold=int(scale("0.2")),
            vote_threshold=int(scale("0.4")),
            time_lock_duration=10,
            proposal_length=10,
            action_level=20,
        ),
        **make_params()
    )
