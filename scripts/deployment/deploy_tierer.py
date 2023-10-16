from brownie import ActionTierConfig, GovernanceManagerProxy  # type: ignore
from brownie import VotingPowerAggregator, StaticTierStrategy  # type: ignore
from brownie import ZERO_ADDRESS
from typing import NamedTuple

from scripts.utils import get_deployer, make_params
from support.types import StrategyConfig


def main():
    deployer = get_deployer()
    # configs = [
    #     StrategyConfig(
    #         VotingPowerAggregator[0],
    #         VotingPowerAggregator.signatures["setSchedule"],
    #         StaticTierStrategy[2],
    #     ),
    #     StrategyConfig(
    #         ZERO_ADDRESS,
    #         ActionTierConfig.signatures["batchSetStrategy"],
    #         StaticTierStrategy[2],
    #     ),
    #     StrategyConfig(
    #         ZERO_ADDRESS,
    #         ActionTierConfig.signatures["setStrategy"],
    #         StaticTierStrategy[2],
    #     ),
    # ]

    deployer.deploy(ActionTierConfig, GovernanceManagerProxy[0], [], **make_params())
