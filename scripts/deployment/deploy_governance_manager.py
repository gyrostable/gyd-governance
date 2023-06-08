from brownie import GovernanceManagerProxy, ProxyAdmin, EmptyContract, GovernanceManager  # type: ignore
from brownie import VotingPowerAggregator, ActionTierConfig, WrappedERC20WithEMA, StaticTierStrategy  # type: ignore

from scripts.utils import get_deployer, get_proxy_admin, make_params


def proxy_admin():
    deployer = get_deployer()
    deployer.deploy(ProxyAdmin, **make_params())


def proxy():
    deployer = get_deployer()
    proxy_admin = get_proxy_admin()
    empty_contract = deployer.deploy(EmptyContract, **make_params())
    deployer.deploy(
        GovernanceManagerProxy, empty_contract, proxy_admin, b"", **make_params()
    )


def main():
    proxy_admin = get_proxy_admin()
    deployer = get_deployer()
    governance_manager = deployer.deploy(
        GovernanceManager,
        VotingPowerAggregator[0],
        ActionTierConfig[0],
        WrappedERC20WithEMA[0],
        **make_params()
    )
    upgradeability_tier_strategy = StaticTierStrategy[0]
    init_data = governance_manager.initialize.encode_input(
        (10, 10e16, upgradeability_tier_strategy)
    )
    proxy_admin.upgradeAndCall(
        GovernanceManagerProxy[0],
        governance_manager,
        init_data,
        make_params({"from": deployer}),
    )
