from brownie import ERC20Mintable, WrappedERC20WithEMA, GovernanceManagerProxy
from scripts.utils import get_deployer, get_gyd_address, make_params
from scripts import constants


def dummy_erc20():
    deployer = get_deployer()
    token = deployer.deploy(ERC20Mintable, **make_params())
    token.mint(deployer, 10_000_000 * 10**18, make_params())


def main():
    deployer = get_deployer()
    deployer.deploy(
        WrappedERC20WithEMA,
        GovernanceManagerProxy[0],
        get_gyd_address(),
        constants.WRAPPED_ERC20_WITH_EMA_WINDOW_WIDTH,
        **make_params(),
    )
