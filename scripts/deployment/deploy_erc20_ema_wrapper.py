from brownie import (
    BoundedERC20WithEMA,
    ERC20Mintable,
    GovernanceManagerProxy,
    TransparentUpgradeableProxy,
)

from scripts import constants
from scripts.utils import get_deployer, get_gyd_address, get_proxy_admin, make_params


def dummy_erc20():
    deployer = get_deployer()
    token = deployer.deploy(ERC20Mintable, **make_params())
    token.mint(deployer, 10_000_000 * 10**18, make_params())


def main():
    deployer = get_deployer()
    deployer.deploy(
        BoundedERC20WithEMA,
        GovernanceManagerProxy[0],
        get_gyd_address(),
        **make_params(),
    )


def proxy():
    deployer = get_deployer()
    bgyd = BoundedERC20WithEMA[0]

    deployer.deploy(
        TransparentUpgradeableProxy,
        bgyd,
        get_proxy_admin(),
        bgyd.initialize.encode_input(constants.BOUNDED_ERC20_WITH_EMA_WINDOW_WIDTH),
        **make_params(),
    )
