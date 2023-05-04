import time

from brownie import GovernanceManagerProxy, MockVault, VotingPowerAggregator  # type: ignore


from scripts.utils import get_deployer, make_params


def main():
    deployer = get_deployer()
    ct = time.time() - 1000
    initial_schedule = ([(MockVault[0], 10**18, 10**18)], ct, ct + 1)

    deployer.deploy(
        VotingPowerAggregator,
        GovernanceManagerProxy[0],
        initial_schedule,
        **make_params()
    )
