from brownie import (
    FriendlyDAOVault,
    MockVault,
    LPVault,
    chain,
    TransparentUpgradeableProxy,
    GovernanceManagerProxy,
    ProxyAdmin,
)
from scripts.constants import GYFI_TOKEN_ADDRESS  # type: ignore

from scripts.utils import get_deployer, make_params


def friendly_dao():
    deployer = get_deployer()
    deployer.deploy(FriendlyDAOVault, deployer, **make_params())


def mock():
    deployer = get_deployer()
    deployer.deploy(MockVault, **make_params())


def lp_vault(lp_token):
    deployer = get_deployer()
    vault = deployer.deploy(
        LPVault, deployer, lp_token, GYFI_TOKEN_ADDRESS[chain.id], **make_params()
    )
    deployer.deploy(
        TransparentUpgradeableProxy,
        vault,
        GovernanceManagerProxy[0],
        vault.initialize.encode_input(86400),  # 1 day withdrawal
        **make_params()
    )
