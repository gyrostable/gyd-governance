import pytest
from brownie import (
    ERC721Mintable,
    ERC20Mintable,
    RecruitNFTVault,
    RecruitNFT,
    StaticTierStrategy,
    FoundingFrogVault,
    accounts,
    chain,
)
from typing import NamedTuple
from eth_account._utils.signing import sign_message_hash
import eth_keys
from hexbytes import HexBytes
from eth_utils import keccak
from eth_abi import encode
from eth_abi.packed import encode_packed
from eip712.messages import EIP712Message

INITIAL_BALANCE = 100

ACCOUNT_KEY = "0x416b8a7d9290502f5661da81f0cf43893e3d19cb9aea3c426cfb36e8186e9c09"
ACCOUNT_ADDRESS = "0x14b0Ed2a7C4cC60DD8F676AE44D0831d3c9b2a9E"
ROOT = "0x9d072b90eca791964a86c0bb8394ead65d9328add64951e77081df8aeff1dcb0"
PROOF = [
    "0x6d59f15c5814d9fddd2e69d1f6f61edd0718e337c41ec74011900c0d736a9fec",
    "0x8e89a990f8382382723aaab6524cce02c64aa67c7e0e6cc0ba139101a1a279ed",
    "0xcd57deac00b520f01cb649a5846e0c6de860c4aceeb4e18f44f0cc3cfcd2b28b",
    "0x007cf7a9076751d7e058320fdf31dacf13a351f5dc08d8bc81ab21ab25d41c64",
]

PROOF_TYPE_HASH = keccak(text="Proof(address account,bytes32[] proof)")
DOMAIN_TYPE_HASH = keccak(
    text="EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
)


class Tier(NamedTuple):
    quorum: int
    proposal_threshold: int
    time_lock_duration: int
    proposal_length: int


def signature(verifying_contract, proof):
    class Proof(EIP712Message):
        # domain
        _name_: "string"
        _version_: "string"
        _chainId_: "uint256"
        _verifyingContract_: "address"

        account: "address"
        proof: "bytes32[]"

    proofToBytes = [bytearray.fromhex(p[2:]) for p in proof]  # strip 0x prefix
    msg = Proof(
        _name_="FoundingFrogVault",
        _version_="1",
        _chainId_=chain.id,
        _verifyingContract_=verifying_contract,
        account=ACCOUNT_ADDRESS,
        proof=proofToBytes,
    )
    local = accounts.add(private_key=ACCOUNT_KEY)
    sm = local.sign_message(msg)
    return sm.signature.hex()


@pytest.fixture(scope="session")
def admin(accounts):
    return accounts[0]


@pytest.fixture(autouse=True)
def isolation_setup(fn_isolation):
    pass


@pytest.fixture
def recruit_nft(admin):
    return admin.deploy(RecruitNFT, "RecruitNFT", "RNFT", admin)


@pytest.fixture
def nft_vault(recruit_nft, admin):
    nft_vault = admin.deploy(
        RecruitNFTVault,
        admin,
        recruit_nft,
    )
    recruit_nft.setGovernanceVault(nft_vault)

    for i in range(5):
        recruit_nft.mint(accounts[i], i)

    return nft_vault


@pytest.fixture
def frog_vault(admin):
    frog_vault = admin.deploy(FoundingFrogVault, admin, 5e18, ROOT)
    return frog_vault


@pytest.fixture
def frog_vault_with_claimed_nfts(frog_vault):
    sig = signature(frog_vault.address, PROOF)
    frog_vault.claimNFT(ACCOUNT_ADDRESS, PROOF, sig)
    return frog_vault


@pytest.fixture
def vault(request, nft_vault, frog_vault_with_claimed_nfts):
    if request.param == "nft_vault":
        return nft_vault
    if request.param == "frog_vault":
        return frog_vault_with_claimed_nfts
    raise ValueError("invalid vault")


def pytest_generate_tests(metafunc):
    if "vault" in metafunc.fixturenames:
        metafunc.parametrize("vault", ["nft_vault", "frog_vault"], indirect=["vault"])


@pytest.fixture
def token(admin):
    c = admin.deploy(ERC20Mintable)
    c.mint(admin, INITIAL_BALANCE)
    return c


@pytest.fixture
def static_tier_strategy(admin):
    return admin.deploy(
        StaticTierStrategy,
        admin,
        Tier(
            quorum=1e17,
            proposal_threshold=2e17,
            time_lock_duration=10,
            proposal_length=10,
        ),
    )
