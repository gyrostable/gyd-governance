import pytest
from brownie import (
    ERC721Mintable,
    ERC20Mintable,
    RaisingERC20,
    RecruitNFTVault,
    RecruitNFT,
    StaticTierStrategy,
    FoundingFrogVault,
    accounts,
    chain,
    ZERO_ADDRESS,
)
from typing import NamedTuple
from eth_account._utils.signing import sign_message_hash
import eth_keys
from hexbytes import HexBytes
from eth_utils import keccak
from eth_abi import encode
from eth_abi.packed import encode_packed
from eip712.messages import EIP712Message

UNDEFINED_BALLOT = 0
FOR_BALLOT = 1
AGAINST_BALLOT = 2
ABSTAIN_BALLOT = 3

PROPOSAL_LENGTH_DURATION = 20
TIMELOCKED_DURATION = 20

QUORUM_NOT_MET_OUTCOME = 1
THRESHOLD_NOT_MET_OUTCOME = 2
SUCCESSFUL_OUTCOME = 3

INITIAL_BALANCE = 100

ACCOUNT_KEY = "0x416b8a7d9290502f5661da81f0cf43893e3d19cb9aea3c426cfb36e8186e9c09"
ACCOUNT_ADDRESS = "0x14b0Ed2a7C4cC60DD8F676AE44D0831d3c9b2a9E"
ROOT = "0x3b0fa5d841dd15eeb43742793d303d92fe5f11a7b4011a0aacb4de21eaa4d722"
PROOF = [
    "0x133d5e46fd4b61ce357008e2433932a1f7b102d00b679a3e7b10b0ec10097176",
    "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
    "0xcc20bdebe234641ec9c9c1c278579ef608f23fb46f1be71cd61a8cb3d6a53735",
]

PROOF_TYPE_HASH = keccak(
    text="Proof(address account,uint128 multiplier,bytes32[] proof)"
)
DOMAIN_TYPE_HASH = keccak(
    text="EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
)


class Tier(NamedTuple):
    quorum: int
    proposal_threshold: int
    vote_threshold: int
    time_lock_duration: int
    proposal_length: int
    action_level: int


def signature(local_account, multiplier, verifying_contract, proof):
    class Proof(EIP712Message):
        # domain
        _name_: "string"
        _version_: "string"
        _chainId_: "uint256"
        _verifyingContract_: "address"

        account: "address"
        multiplier: "uint128"
        proof: "bytes32[]"

    proofToBytes = [bytearray.fromhex(p[2:]) for p in proof]  # strip 0x prefix
    msg = Proof(
        _name_="FoundingFrogVault",
        _version_="1",
        _chainId_=chain.id,
        _verifyingContract_=verifying_contract,
        account=local_account.address,
        # Coerce to int, since numbers created using e-notation are created as floats, not
        # ints. This results in eip712 being unable to encode the number to a uint128
        # type.
        multiplier=int(multiplier),
        proof=proofToBytes,
    )
    sm = local_account.sign_message(msg)
    return sm.signature.hex()


@pytest.fixture()
def local_account(accounts):
    return accounts.add(private_key=ACCOUNT_KEY)


@pytest.fixture(scope="session")
def admin(accounts):
    return accounts[0]


@pytest.fixture(scope="session")
def dummy_dao_addresses():
    return [
        "0xa7588b0d49cB5B9e7447aaBe6299F2EaB83Cf55A",
        "0xF09E651C2E5537Ea2230eb6EaCAEF215f749f590",
        "0xF317Ec282d4a5f838a34970Fb9D87ACf369D76aA",
    ]


@pytest.fixture(scope="module")
def friendly_dao_vault(admin, FriendlyDAOVault):
    return admin.deploy(FriendlyDAOVault, admin)


@pytest.fixture(scope="module")
def voting_power_aggregator(admin, VotingPowerAggregator):
    return admin.deploy(VotingPowerAggregator, admin)


@pytest.fixture(scope="module")
def mock_tierer(admin, MockTierer):
    return admin.deploy(MockTierer, (2e17, 1e17, 1e17, 20, 20, 20))


@pytest.fixture(scope="module")
def wrapped_erc20(admin, WrappedERC20WithEMA, token):
    return admin.deploy(WrappedERC20WithEMA, admin, token.address, 2e18)


@pytest.fixture(scope="module")
def governance_manager(
    admin,
    GovernanceManager,
    voting_power_aggregator,
    mock_tierer,
    upgradeability_tier_strategy,
    wrapped_erc20,
):
    return admin.deploy(
        GovernanceManager,
        voting_power_aggregator,
        mock_tierer,
        (10, 10e16, upgradeability_tier_strategy),
        wrapped_erc20,
    )


@pytest.fixture(scope="module")
def raising_token(admin):
    return admin.deploy(RaisingERC20)


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
def frog_vault_with_claimed_nfts(local_account, frog_vault):
    sig = signature(local_account, 1e18, frog_vault.address, PROOF)
    frog_vault.claimNFT(ACCOUNT_ADDRESS, 1e18, PROOF, sig)
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


@pytest.fixture(scope="module")
def token(admin):
    c = admin.deploy(ERC20Mintable)
    c.mint(admin, INITIAL_BALANCE)
    return c


@pytest.fixture(scope="module")
def static_tier_strategy(admin):
    return admin.deploy(
        StaticTierStrategy,
        admin,
        Tier(
            quorum=1e17,
            proposal_threshold=2e17,
            vote_threshold=2e17,
            time_lock_duration=10,
            proposal_length=10,
            action_level=10,
        ),
    )


@pytest.fixture(scope="module")
def upgradeability_tier_strategy(admin):
    return admin.deploy(
        StaticTierStrategy,
        admin,
        Tier(
            quorum=2e17,
            proposal_threshold=2e17,
            vote_threshold=4e17,
            time_lock_duration=10,
            proposal_length=10,
            action_level=20,
        ),
    )
