from brownie import ActionTierConfig, GovernanceManagerProxy  # type: ignore
from brownie import VotingPowerAggregator, StaticTierStrategy  # type: ignore
from typing import NamedTuple

from scripts.utils import get_deployer, make_params


class StrategyConfig(NamedTuple):
    contract: str
    sig: str
    strategy: str


def main():
    deployer = get_deployer()
    configs = [
        StrategyConfig(
            VotingPowerAggregator[0],
            VotingPowerAggregator.signatures["setSchedule"],
            StaticTierStrategy[1],
        ),
    ]

    deployer.deploy(
        ActionTierConfig, GovernanceManagerProxy[0], configs, **make_params()
    )
