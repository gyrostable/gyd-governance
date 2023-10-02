from typing import NamedTuple

import eth_keys
import pytest
from brownie import (
    ZERO_ADDRESS,
    CouncillorNFT,
    CouncillorNFTVault,
    ERC20Mintable,
    ERC721Mintable,
    FoundingMemberVault,
    RaisingERC20,
    StaticTierStrategy,
    accounts,
    chain,
)
from eip712.messages import EIP712Message
from eth_abi import encode
from eth_abi.packed import encode_packed
from eth_account._utils.signing import sign_message_hash
from eth_utils import keccak
from hexbytes import HexBytes

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


def signature(local_account, receiver, delegate, multiplier, verifying_contract, proof):
    class Proof(EIP712Message):
        # domain
        _name_: "string"
        _version_: "string"
        _chainId_: "uint256"
        _verifyingContract_: "address"

        account: "address"
        receiver: "address"
        delegate: "address"
        multiplier: "uint128"
        proof: "bytes32[]"

    proofToBytes = [bytearray.fromhex(p[2:]) for p in proof]  # strip 0x prefix
    msg = Proof(
        _name_="FoundingMemberVault",
        _version_="1",
        _chainId_=chain.id,
        _verifyingContract_=verifying_contract,
        account=local_account.address,
        receiver=receiver.address,
        delegate=delegate.address,
        # Coerce to int, since numbers created using e-notation are created as floats, not
        # ints. This results in eip712 being unable to encode the number to a uint128
        # type.
        multiplier=int(multiplier),
        proof=proofToBytes,
    )
    sm = local_account.sign_message(msg)
    return sm.signature.hex()


@pytest.fixture(scope="module")
def local_account(accounts):
    local_account = accounts.add(private_key=ACCOUNT_KEY)
    accounts[5].transfer(to=local_account, amount="1 ether")
    return local_account


@pytest.fixture(scope="session")
def admin(accounts):
    return accounts[0]


@pytest.fixture(scope="session")
def alice(accounts):
    return accounts[1]


@pytest.fixture(scope="session")
def bob(accounts):
    return accounts[2]


@pytest.fixture(scope="session")
def charlie(accounts):
    return accounts[3]


@pytest.fixture(scope="session")
def treasury(accounts):
    return accounts[8]


@pytest.fixture(scope="session")
def dummy_dao_addresses():
    return [
        "0xa7588b0d49cB5B9e7447aaBe6299F2EaB83Cf55A",
        "0xF09E651C2E5537Ea2230eb6EaCAEF215f749f590",
        "0xF317Ec282d4a5f838a34970Fb9D87ACf369D76aA",
    ]


@pytest.fixture(scope="module")
def associated_dao_vault(admin, AssociatedDAOVault):
    return admin.deploy(AssociatedDAOVault, admin)


@pytest.fixture(scope="module")
def mock_vault(MockVault, admin, alice, chain):
    mock_vault = admin.deploy(MockVault)
    mock_vault.updateVotingPower(alice, 50e18)
    mock_vault.updateVotingPower(admin, 50e18)
    chain.sleep(1)
    chain.mine()
    return mock_vault


@pytest.fixture(scope="module")
def voting_power_aggregator(
    admin, chain, mock_vault, VotingPowerAggregator, governance_manager_proxy
):
    ct = chain.time() - 1000
    initial_schedule = ([(mock_vault, 10**18, 10**18)], ct, ct + 1)
    return admin.deploy(
        VotingPowerAggregator, governance_manager_proxy, initial_schedule
    )


@pytest.fixture(scope="module")
def time_settable_voting_power_aggregator(
    admin, MockVault, chain, TimeSettableVotingPowerAggregator
):
    mv = admin.deploy(MockVault)
    ct = chain.time() - 1000
    initial_schedule = ([(mv, 10**18, 10**18)], ct, ct + 1)
    return admin.deploy(TimeSettableVotingPowerAggregator, admin, initial_schedule)


@pytest.fixture(scope="module")
def mock_tierer(admin, MockTierer):
    return admin.deploy(MockTierer, (2e17, 1e17, 1e17, 20, 20, 20))


@pytest.fixture(scope="module")
def bounded_erc20(admin, BoundedERC20WithEMA, token):
    return admin.deploy(BoundedERC20WithEMA, admin, token.address, 2e18)


@pytest.fixture(scope="module")
def governance_manager_impl(
    admin,
    TestingGovernanceManager,
    voting_power_aggregator,
    mock_tierer,
):
    return admin.deploy(TestingGovernanceManager, voting_power_aggregator, mock_tierer)


@pytest.fixture(scope="module")
def proxy_admin(admin, ProxyAdmin):
    return admin.deploy(ProxyAdmin)


@pytest.fixture(scope="module")
def governance_manager_proxy(GovernanceManagerProxy, EmptyContract, admin, proxy_admin):
    empty_contract = admin.deploy(EmptyContract)
    return admin.deploy(GovernanceManagerProxy, empty_contract, proxy_admin, b"")


@pytest.fixture(scope="module")
def governance_manager(
    admin,
    governance_manager_impl,
    governance_manager_proxy,
    proxy_admin,
    upgradeability_tier_strategy,
    TestingGovernanceManager,
    GovernanceManagerProxy,
    bounded_erc20,
):
    proxy_admin.upgrade(
        governance_manager_proxy, governance_manager_impl, {"from": admin}
    )
    GovernanceManagerProxy.remove(governance_manager_proxy)
    gov_manager = TestingGovernanceManager.at(
        governance_manager_proxy.address, owner=admin
    )
    init_data = governance_manager_impl.initializeUpgradeabilityParams.encode_input(
        bounded_erc20, (10, 10**16, upgradeability_tier_strategy)
    )
    gov_manager.executeCall(gov_manager, init_data, {"from": admin})
    return gov_manager


@pytest.fixture(scope="module")
def raising_token(admin):
    return admin.deploy(RaisingERC20)


@pytest.fixture(autouse=True)
def isolation_setup(fn_isolation):
    pass


@pytest.fixture
def councillor_nft(admin):
    return admin.deploy(CouncillorNFT, "CouncillorNFT", "RNFT", admin, 10, ROOT)


@pytest.fixture
def nft_vault(councillor_nft, admin):
    nft_vault = admin.deploy(
        CouncillorNFTVault,
        admin,
        councillor_nft,
    )
    councillor_nft.initializeGovernanceVault(nft_vault)

    for i in range(5):
        councillor_nft.mint(accounts[i], accounts[i], PROOF, i)

    return nft_vault


@pytest.fixture
def founding_member_vault(admin):
    founding_member_vault = admin.deploy(FoundingMemberVault, admin, 5e18, ROOT)
    return founding_member_vault


@pytest.fixture
def founding_member_vault_with_claimed_nfts(
    local_account, founding_member_vault, admin
):
    sig = signature(
        local_account, admin, admin, 1e18, founding_member_vault.address, PROOF
    )
    founding_member_vault.claimNFT(ACCOUNT_ADDRESS, admin, 1e18, PROOF, sig)
    return founding_member_vault


@pytest.fixture
def vault(request, nft_vault, founding_member_vault_with_claimed_nfts):
    if request.param == "nft_vault":
        return nft_vault
    if request.param == "founding_member_vault":
        return founding_member_vault_with_claimed_nfts
    raise ValueError("invalid vault")


def pytest_generate_tests(metafunc):
    if "vault" in metafunc.fixturenames:
        metafunc.parametrize(
            "vault", ["nft_vault", "founding_member_vault"], indirect=["vault"]
        )


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


@pytest.fixture
def under_tier():
    return Tier(
        quorum=2e17,
        vote_threshold=2e17,
        proposal_threshold=2e17,
        time_lock_duration=20,
        proposal_length=20,
        action_level=10,
    )


@pytest.fixture
def over_tier():
    return Tier(
        quorum=5e17,
        vote_threshold=2e17,
        proposal_threshold=2e17,
        time_lock_duration=20,
        proposal_length=20,
        action_level=10,
    )
