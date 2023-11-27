from brownie import (
    ActionTierConfig,
    EmptyContract,
    GovernanceManager,
    GovernanceManagerProxy,
    MultiownerProxyAdmin,
    VotingPowerAggregator,
)
from brownie import chain
from scripts.constants import (
    ACTION_LEVEL_THRESHOLD,
    BGYD,
    EMA_THRESHOLD,
    MIN_BGYD_SUPPLY,
    STRATEGIES,
)

from scripts.utils import (
    get_deployer,
    get_governance_proxy_admin,
    get_multisig_address,
    make_params,
)
from support.types import LimitUpgradeabilityParams


def proxy_admin():
    deployer = get_deployer()
    deployer.deploy(MultiownerProxyAdmin, **make_params())


def proxy():
    deployer = get_deployer()
    proxy_admin = get_governance_proxy_admin()
    empty_contract = deployer.deploy(EmptyContract, **make_params())
    deployer.deploy(
        GovernanceManagerProxy, empty_contract, proxy_admin, b"", **make_params()
    )


def main():
    proxy_admin = get_governance_proxy_admin()
    deployer = get_deployer()
    multisig = get_multisig_address()
    governance_manager = deployer.deploy(
        GovernanceManager,
        multisig,  # type: ignore
        VotingPowerAggregator[0],
        ActionTierConfig[0],
        **make_params()
    )

    limit_upgradeability_params = LimitUpgradeabilityParams(
        action_level_threshold=ACTION_LEVEL_THRESHOLD,
        ema_threshold=EMA_THRESHOLD,
        min_bgyd_supply=MIN_BGYD_SUPPLY,
        tier_strategy=STRATEGIES[chain.id]["limit_upgradeability"],
    )

    proxy_admin.upgradeAndCall(
        GovernanceManagerProxy[0],
        governance_manager,
        governance_manager.initialize.encode_input(
            BGYD[chain.id],
            limit_upgradeability_params,
        ),
        make_params({"from": deployer}),
    )
