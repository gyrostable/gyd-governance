import pytest
from brownie import ERC721Mintable, RecruitNFTVault, FoundingFrogVault, accounts
from eth_account._utils.signing import sign_message_hash
import eth_keys
from hexbytes import HexBytes
from eth_utils import keccak
from eth_abi import encode
from eth_abi.packed import encode_packed

ACCOUNT_KEY = "0x416b8a7d9290502f5661da81f0cf43893e3d19cb9aea3c426cfb36e8186e9c09"
ACCOUNT_ADDRESS = "0x14b0Ed2a7C4cC60DD8F676AE44D0831d3c9b2a9E"
ROOT = "0x9d072b90eca791964a86c0bb8394ead65d9328add64951e77081df8aeff1dcb0"
PROOF = [
    "0x6d59f15c5814d9fddd2e69d1f6f61edd0718e337c41ec74011900c0d736a9fec",
    "0x8e89a990f8382382723aaab6524cce02c64aa67c7e0e6cc0ba139101a1a279ed",
    "0xcd57deac00b520f01cb649a5846e0c6de860c4aceeb4e18f44f0cc3cfcd2b28b",
    "0x007cf7a9076751d7e058320fdf31dacf13a351f5dc08d8bc81ab21ab25d41c64",
]

PROOF_TYPE_HASH = keccak(text="Proof(address owner,bytes32[] elements)")
DOMAIN_TYPE_HASH = keccak(
    text="EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
)


def signature(verifying_contract):
    # (cedric): DRAGON AHEAD!
    # I tried multiple different libraries to encode a struct in an EIP712-compliant way,
    # but all had issues which meant I couldn't generate a valid signature:
    # - `eip712` (used by Brownie) didn't support the v4 standard which allows array
    # attributes in the data struct.
    # - `py-eip712-structs` failed to generate the correct structHash.
    # Therefore, I've encoded it manually below, resulting in much nastiness.

    # This coercion from hex string to bytes is required. Without it the subsequent call
    # to `encode` raises.
    proofToBytes = [bytearray.fromhex(p[2:]) for p in PROOF]  # strip 0x prefix
    structHash = keccak(
        encode(
            ["bytes32", "address", "bytes32[]"],
            [PROOF_TYPE_HASH, ACCOUNT_ADDRESS, proofToBytes],
        )
    )
    domainTypeHash = keccak(DOMAIN_TYPE_HASH)
    domainStructHash = keccak(
        encode(
            [
                "bytes32",
                "bytes32",  # ----v
                "bytes32",  # Strings are encoded as keccak hashes in the standard.
                "uint256",
                "address",
            ],
            [
                DOMAIN_TYPE_HASH,
                keccak(text="FoundingFrogVault"),
                keccak(text="1"),
                1,
                verifying_contract,
            ],
        )
    )
    pk = eth_keys.keys.PrivateKey(HexBytes(ACCOUNT_KEY))
    signable_message = keccak(
        encode_packed(
            ["bytes", "bytes32", "bytes32"], [b"\x19\x01", domainStructHash, structHash]
        )
    )
    (v, r, s, signature) = sign_message_hash(pk, signable_message)
    return signature


@pytest.fixture(scope="session")
def admin(accounts):
    return accounts[0]


@pytest.fixture(autouse=True)
def isolation_setup(fn_isolation):
    pass


@pytest.fixture
def nft(ERC721Mintable, admin):
    contract = admin.deploy(ERC721Mintable)
    for i in range(5):
        contract.mint(accounts[i], i)

    return contract


@pytest.fixture
def nft_vault(nft, admin):
    return admin.deploy(RecruitNFTVault, admin, nft)


@pytest.fixture
def frog_vault(admin):
    frog_vault = admin.deploy(FoundingFrogVault, admin, 5, ROOT)
    return frog_vault


@pytest.fixture
def frog_vault_with_claimed_nfts(frog_vault):
    frog_vault.claimNFT(ACCOUNT_ADDRESS, PROOF, signature(frog_vault.address))
    return frog_vault


@pytest.fixture
def vault(request, nft_vault, frog_vault_with_claimed_nfts):
    if request.param == "nft_vault":
        return nft_vault
    if request.param == "frog_vault":
        return frog_vault_with_claimed_nfts
    raise ValueError("invalid vault")
