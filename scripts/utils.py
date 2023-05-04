import os

from brownie import ERC20Mintable, ProxyAdmin, accounts, chain  # type: ignore

from scripts import constants

PROXY_ADMIN_POLYGON = "0x83d34ca335d197bcFe403cb38E82CBD734C4CbBE"


def get_deployer():
    return accounts[0]


def get_gyd_address():
    if chain.id == 1337:
        return ERC20Mintable[0]
    return constants.GYD_TOKEN_ADDRESS[chain.id]


def get_proxy_admin():
    if chain.id == 1337:
        return ProxyAdmin[0]
    if chain.id == 137:
        return ProxyAdmin(PROXY_ADMIN_POLYGON)
    raise ValueError("Unknown chain id")


def make_params(extra_params=None):
    if extra_params is None:
        extra_params = {}
    params = extra_params.copy()
    if "BROWNIE_PRIORITY_GWEI" in os.environ:
        params["priority_fee"] = os.environ["BROWNIE_PRIORITY_GWEI"] + " gwei"
    else:
        gas_price = os.environ.get("BROWNIE_GAS_GWEI", "50")
        params["gas_price"] = gas_price + " gwei"
    return params
