import json
from typing import NamedTuple

from brownie import (
    AggregateLPVault,
    AssociatedDAOVault,
    CouncillorNFT,
    CouncillorNFTVault,
    FoundingMemberVault,
    GovernanceManagerProxy,
    LockedVaultWithThreshold,
    LockedVault,
    MockVault,
    ProxyAdmin,
    TransparentUpgradeableProxy,
    chain,
    interface,
)

from scripts.constants import AGGREGATE_VAULT_THRESHOLD, COUNCILLOR_NFT_MAX_SUPPLY, DAO_TREASURY, ECLP_PRICE_ORACLE, GYFI_TOKEN_ADDRESS, GYFI_TOTAL_SUPLY, VAULTS  # type: ignore
from scripts.utils import get_deployer, get_proxy_admin, make_params


def associated_dao():
    deployer = get_deployer()
    deployer.deploy(AssociatedDAOVault, GovernanceManagerProxy[0], **make_params())


def mock():
    deployer = get_deployer()
    deployer.deploy(MockVault, **make_params())


def locked_vault(underlying):
    deployer = get_deployer()
    vault = deployer.deploy(
        LockedVault,
        GovernanceManagerProxy[0],
        underlying,
        GYFI_TOKEN_ADDRESS[chain.id],
        DAO_TREASURY[chain.id],
        **make_params()
    )
    deployer.deploy(
        TransparentUpgradeableProxy,
        vault,
        get_proxy_admin(),
        vault.initialize.encode_input(2592000),  # 30 days withdrawal
        **make_params()
    )


def gyfi_vault():
    deployer = get_deployer()
    vault = deployer.deploy(
        LockedVaultWithThreshold,
        deployer,
        GYFI_TOKEN_ADDRESS[chain.id],
        GYFI_TOKEN_ADDRESS[chain.id],
        GYFI_TOTAL_SUPLY // 10,
        DAO_TREASURY[chain.id],
        **make_params()
    )
    deployer.deploy(
        TransparentUpgradeableProxy,
        vault,
        get_proxy_admin(),
        vault.initialize.encode_input(2592000),  # 30 days withdrawal
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


def councillor_nft(proofs_file):
    deployer = get_deployer()
    with open(proofs_file) as f:
        data = json.load(f)
    deployer.deploy(
        CouncillorNFT,
        "Gyroscope Councillor Vault",
        "GCVT",
        GovernanceManagerProxy[0],
        COUNCILLOR_NFT_MAX_SUPPLY,
        data["root"],
        **make_params()
    )


def councillor_nft_vault():
    deployer = get_deployer()
    deployer.deploy(
        CouncillorNFTVault,
        GovernanceManagerProxy[0],
        CouncillorNFT[-1],
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
        AggregateLPVault,
        GovernanceManagerProxy[0],
        AGGREGATE_VAULT_THRESHOLD,
        pool_weights,
        **make_params()
    )


def compute_lp_vault_weights():
    aggregate_lp_vault = AggregateLPVault[-1]
    vaults = VAULTS[chain.id]["lp_vaults"]
    underlyings = [interface.ILockingVault(v).underlying() for v in vaults]
    oracle = interface.IPriceOracle(ECLP_PRICE_ORACLE)
    prices = [oracle.getPriceUSD(u) for u in underlyings]
    total_weight = sum(prices)
    normalized_weights = [p * 10**18 // total_weight for p in prices]
    vault_weights = [VaultWeight(v, w) for v, w in zip(vaults, normalized_weights)]

    set_vault_call = aggregate_lp_vault.setVaultWeights.encode_input(vault_weights)
    print(json.dumps([(aggregate_lp_vault.address, set_vault_call)]))
