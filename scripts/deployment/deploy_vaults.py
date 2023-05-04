from brownie import FriendlyDAOVault, MockVault  # type: ignore

from scripts.utils import get_deployer, make_params


def friendly_dao():
    deployer = get_deployer()
    deployer.deploy(FriendlyDAOVault, deployer, **make_params())


def mock():
    deployer = get_deployer()
    deployer.deploy(MockVault, **make_params())
