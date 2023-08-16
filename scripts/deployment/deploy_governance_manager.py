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
        **make_params()
    )

    proxy_admin.upgrade(
        GovernanceManagerProxy[0],
        governance_manager,
        make_params({"from": deployer}),
    )
