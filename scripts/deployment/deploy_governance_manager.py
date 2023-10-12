from brownie import (
    ActionTierConfig,
    BoundedERC20WithEMA,  # type: ignore
    EmptyContract,
    GovernanceManager,
    GovernanceManagerProxy,
    ProxyAdmin,
    MultiownerProxyAdmin,
    StaticTierStrategy,
    VotingPowerAggregator,
)

from scripts.utils import (
    get_deployer,
    get_governance_proxy_admin,
    get_multisig_address,
    make_params,
)


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

    proxy_admin.upgrade(
        GovernanceManagerProxy[0],
        governance_manager,
        make_params({"from": deployer}),
    )
