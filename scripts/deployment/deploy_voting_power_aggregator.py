import json
import time

from brownie import GovernanceManagerProxy, MockVault, VotingPowerAggregator, chain
from scripts.constants import VAULTS  # type: ignore


from scripts.utils import get_deployer, make_params
from support.types import VaultWeightConfiguration, VaultWeightSchedule
from support.utils import scale

DEPLOYMENT_TIME = 1697457642


# FoundingMemberVault	initialWeight	uint256	30.0%
# 	targetWeight	uint256	15.0%
# CouncillorVault	initialWeight	uint256	30.0%
# 	targetWeight	uint256	17.5%
# AssociatedDAOVault	initialWeight	uint256	30.0%
# 	targetWeight	uint256	17.5%
# AggregateLPVault	initialWeight	uint256	10.0%
# 	targetWeight	uint256	15.0%
# GYFIVault	initialWeight	uint256	0.0%
# 	targetWeight	uint256	35.0%

vaults = [
    VaultWeightConfiguration(
        vault_address=VAULTS[chain.id]["founding_members"],
        initial_weight=int(scale("0.30")),
        target_weight=int(scale("0.15")),
    ),
    VaultWeightConfiguration(
        vault_address=VAULTS[chain.id]["councillor"],
        initial_weight=int(scale("0.30")),
        target_weight=int(scale("0.175")),
    ),
    VaultWeightConfiguration(
        vault_address=VAULTS[chain.id]["dao"],
        initial_weight=int(scale("0.30")),
        target_weight=int(scale("0.175")),
    ),
    VaultWeightConfiguration(
        vault_address=VAULTS[chain.id]["aggregate"],
        initial_weight=int(scale("0.10")),
        target_weight=int(scale("0.15")),
    ),
    VaultWeightConfiguration(
        vault_address=VAULTS[chain.id]["gyfi"],
        initial_weight=int(scale("0")),
        target_weight=int(scale("0.35")),
    ),
]


def main():
    schedule = VaultWeightSchedule(
        starts_at=DEPLOYMENT_TIME,
        ends_at=DEPLOYMENT_TIME + 4 * 365 * 86400,  # 4 years later
        vaults=vaults,
    )
    deployer = get_deployer()

    deployer.deploy(
        VotingPowerAggregator, GovernanceManagerProxy[0], schedule, **make_params()
    )


def set_schedule():
    current_time = int(time.time())
    schedule = VaultWeightSchedule(
        starts_at=current_time,
        ends_at=current_time + 4 * 365 * 86400,  # 4 years later
        vaults=vaults,
    )

    print(
        json.dumps(
            [
                (
                    VotingPowerAggregator[0].address,
                    VotingPowerAggregator[0].setSchedule.encode_input(schedule),
                )
            ]
        )
    )
