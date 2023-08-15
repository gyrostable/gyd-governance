import json
from typing import NamedTuple

from brownie import (AggregateLPVault, AssociatedDAOVault, FoundingMemberVault,
                     GovernanceManagerProxy, LPVault, MockVault, ProxyAdmin,
                     TransparentUpgradeableProxy, chain)

from scripts.constants import GYFI_TOKEN_ADDRESS  # type: ignore
from scripts.utils import get_deployer, make_params


def associated_dao():
    deployer = get_deployer()
    deployer.deploy(AssociatedDAOVault, deployer, **make_params())


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


def founding_member_vault(proofs_file):
    deployer = get_deployer()
    with open(proofs_file) as f:
        data = json.load(f)
    sum_voting_power = sum(int(d["multiplier"]) for d in data["proofs"])
    deployer.deploy(
        FoundingMemberVault,
        GovernanceManagerProxy[0],
        sum_voting_power,
        data["root"],
        **make_params()
    )


class VaultWeight(NamedTuple):
    vault_address: str
    weight: int


def aggregate_lp_vault(config_file):
    with open(config_file) as f:
        pool_weights = [VaultWeight(**v) for v in json.load(f)]
    deployer = get_deployer()
    deployer.deploy(
        AggregateLPVault, GovernanceManagerProxy[0], 0, pool_weights, **make_params()
    )
