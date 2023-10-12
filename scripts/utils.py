import os
from typing import cast

from brownie import ERC20Mintable, ProxyAdmin, accounts, chain, MultiownerProxyAdmin  # type: ignore
from brownie.network.account import LocalAccount

from scripts import constants

BROWNIE_ACCOUNT_PASSWORD = os.environ.get("BROWNIE_ACCOUNT_PASSWORD")
DEV = os.environ.get("DEV", "0").lower() in ["1", "true", "yes"]

PROXY_ADMIN_POLYGON = "0x83d34ca335d197bcFe403cb38E82CBD734C4CbBE"
PROXY_ADMIN_MAINNET = "0xC77fd1c986C8d1F084DAFb0FF43FbD19cf92dbFb"
MULTISIG_ADDRESS_MAINNET = "0x2d9FaF0b633FF6c4170E171dAe80909f3D03453C"


def get_deployer():
    if chain.id == 137:  # polygon
        return cast(
            LocalAccount, accounts.load("gyro-deployer", BROWNIE_ACCOUNT_PASSWORD)  # type: ignore
        )
    if chain.id == 1:  # polygon
        return cast(
            LocalAccount, accounts.load("gyroscope-foundation-deployer", BROWNIE_ACCOUNT_PASSWORD)  # type: ignore
        )

    return accounts[0]


def get_gyd_address():
    if chain.id == 1337:
        return ERC20Mintable[0]
    return constants.GYD_TOKEN_ADDRESS[chain.id]


def get_proxy_admin():
    if chain.id == 1337 or DEV:
        return ProxyAdmin[0]
    if chain.id == 137:
        return ProxyAdmin.at(PROXY_ADMIN_POLYGON)
    if chain.id == 1:
        return ProxyAdmin.at(PROXY_ADMIN_MAINNET)
    raise ValueError("Unknown chain id")


def get_multisig_address():
    if chain.id == 1337 or DEV:
        return accounts[1]
    if chain.id == 1:
        return accounts.at(MULTISIG_ADDRESS_MAINNET, force=True)
    raise ValueError("Unknown chain id")


def get_governance_proxy_admin():
    return MultiownerProxyAdmin[0]


def make_params(extra_params=None):
    if extra_params is None:
        extra_params = {}
    params = extra_params.copy()
    params["required_confs"] = 1
    if chain.id == 137:
        params["required_confs"] = 3
    if "BROWNIE_PRIORITY_GWEI" in os.environ:
        params["priority_fee"] = os.environ["BROWNIE_PRIORITY_GWEI"] + " gwei"
    else:
        gas_price = os.environ.get("BROWNIE_GWEI", "50")
        params["gas_price"] = gas_price + " gwei"
    return params
