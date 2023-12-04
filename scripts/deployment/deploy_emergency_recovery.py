import time
from brownie import GovernanceManagerProxy, MultiownerProxyAdmin, EmergencyRecovery

from scripts.constants import EMERGENCY_RECOVERY_MULTISIG
from scripts.utils import get_deployer, make_params


def main():
    deployer = get_deployer()

    timelock_duration = 3 * 7 * 86400  # 3 weeks in seconds
    vote_threshold = 10**17  # 10%
    four_years_in_second = 4 * 365 * 86400

    deployer.deploy(
        EmergencyRecovery,
        GovernanceManagerProxy[0],  # governance,
        MultiownerProxyAdmin[0],  # proxyAdmin,
        EMERGENCY_RECOVERY_MULTISIG,  # type: ignore , safeAddress,
        int(time.time()) + four_years_in_second,  # type: ignore , sunsetAt,
        vote_threshold,  # type: ignore vetoThreshold,
        timelock_duration,  # type: ignore , timelockDuration
        **make_params(),
    )
