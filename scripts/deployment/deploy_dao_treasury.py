from brownie import EmptyContract, TransparentUpgradeableProxy

from scripts.utils import get_deployer, get_proxy_admin, make_params


def proxy():
    deployer = get_deployer()
    proxy_admin = get_proxy_admin()
    empty_contract = deployer.deploy(EmptyContract, **make_params())
    deployer.deploy(
        TransparentUpgradeableProxy, empty_contract, proxy_admin, b"", **make_params()
    )
