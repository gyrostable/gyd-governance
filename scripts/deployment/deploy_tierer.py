from brownie import ActionTierConfig, GovernanceManagerProxy  # type: ignore

from scripts.utils import get_deployer, make_params


def main():
    deployer = get_deployer()
    deployer.deploy(ActionTierConfig, GovernanceManagerProxy[0], **make_params())
