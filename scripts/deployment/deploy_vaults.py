from brownie import FriendlyDAOVault

from scripts.utils import get_deployer, make_params


def friendly_dao():
    deployer = get_deployer()
    deployer.deploy(FriendlyDAOVault, deployer, **make_params())
