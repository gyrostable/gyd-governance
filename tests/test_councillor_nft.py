import random
from brownie import chain, reverts
from eip712.messages import EIP712Message
from eth_abi.packed import encode_packed
from eth_utils import keccak


def test_councillor_nft_is_not_transferable(admin, accounts, councillor_nft, nft_vault):
    with reverts("cannot transfer NFT"):
        councillor_nft.transferFrom(admin, accounts[1], 0)


def test_councillor_nft_is_mintable_by_owner(
    admin, accounts, councillor_nft, nft_vault
):
    acc = accounts[1]
    with reverts("ECDSA: invalid signature length"):
        councillor_nft.mint(acc, acc, [], b"", {"from": acc})

    a = accounts.add()
    councillor_nft.mint(a, a, [], b"", {"from": admin})


def test_councillor_nft_supply_cap(admin, accounts, councillor_nft, nft_vault):
    # this brings the total of NFTs minted to the max supply
    for _ in range(councillor_nft.maxSupply() - councillor_nft.totalSupply()):
        a = accounts.add()
        councillor_nft.mint(a, a, [], b"", {"from": admin})

    assert councillor_nft.totalSupply() == councillor_nft.maxSupply()

    a = accounts.add()
    with reverts("mint error: supply cap would be exceeded"):
        councillor_nft.mint(a, a, [], b"", {"from": admin})


def signature(to, delegate, proof, verifying_contract):
    class Proof(EIP712Message):
        _name_: "string"
        _version_: "string"
        _chainId_: "uint256"
        _verifyingContract_: "address"

        to: "address"
        delegate: "address"
        proof: "bytes32[]"

    proofB = [bytearray.fromhex(p[2:]) for p in proof]
    msg = Proof(
        _name_="CouncillorNFT",
        _version_="1",
        _chainId_=chain.id,
        _verifyingContract_=verifying_contract,
        to=to.address,
        delegate=delegate.address,
        proof=proofB,
    )

    sm = to.sign_message(msg)
    return sm.signature.hex()


ROOT = "0xfcd11faacaee1c4654d0175b12a0a45870442d680639097d2f3baa754ba8be27"
PROOF = [
    "0xa96ba5eff69d2c1c3160cd10f130789fde827b071f22596664de70d4da817807",
    "0xa3f1aebd18f2581bae68275cb502db4b17b2490f841048a4fa2b41dbe3f75975",
]


def test_councillor_nft_is_mintable_by_allowlisted_address(
    admin, local_account, CouncillorNFT, CouncillorNFTVault
):
    councillor_nft = admin.deploy(
        CouncillorNFT, "CouncillorNFT", "RNFT", admin, 10, ROOT
    )
    nft_vault = admin.deploy(CouncillorNFTVault, admin, councillor_nft)
    councillor_nft.initializeGovernanceVault(nft_vault.address)

    sig = signature(local_account, local_account, PROOF, councillor_nft.address)
    councillor_nft.mint(
        local_account, local_account, PROOF, sig, {"from": local_account}
    )

    assert councillor_nft.balanceOf(local_account) == 1


def test_councillor_nft_voting_power_can_be_delegated(
    admin, local_account, CouncillorNFT, CouncillorNFTVault, accounts
):
    councillor_nft = admin.deploy(
        CouncillorNFT, "CouncillorNFT", "RNFT", admin, 10, ROOT
    )
    nft_vault = admin.deploy(CouncillorNFTVault, admin, councillor_nft)
    councillor_nft.initializeGovernanceVault(nft_vault.address)

    other_account = accounts[4]

    sig = signature(local_account, other_account, PROOF, councillor_nft.address)
    councillor_nft.mint(
        local_account, other_account, PROOF, sig, {"from": local_account}
    )

    assert councillor_nft.balanceOf(local_account) == 1
    assert nft_vault.getRawVotingPower(local_account) == 0
    assert nft_vault.getRawVotingPower(other_account) == 1e18


def test_councillor_nft_is_mintable_only_once(
    admin,
    alice,
    bob,
    local_account,
    CouncillorNFT,
    CouncillorNFTVault,
):
    councillor_nft = admin.deploy(
        CouncillorNFT, "CouncillorNFT", "RNFT", admin, 10, ROOT
    )
    nft_vault = admin.deploy(CouncillorNFTVault, admin, councillor_nft)
    councillor_nft.initializeGovernanceVault(nft_vault.address)

    sig = signature(local_account, local_account, PROOF, councillor_nft.address)
    councillor_nft.mint(
        local_account, local_account, PROOF, sig, {"from": local_account}
    )

    with reverts("user has already claimed NFT"):
        councillor_nft.mint(local_account, local_account, PROOF, sig, {"from": alice})

    with reverts("user has already claimed NFT"):
        councillor_nft.mint(local_account, local_account, PROOF, sig, {"from": bob})
        # councillor_nft.mint(local_account, PROOF, sig, {"from": bob})


def test_update_minting_params(councillor_nft, alice):
    new_merkle_root = "0x" + random.randint(0, 2**256 - 1).to_bytes(32, "big").hex()

    with reverts():
        councillor_nft.updateMintingParams(100, new_merkle_root, {"from": alice})

    councillor_nft.updateMintingParams(100, new_merkle_root)
    assert councillor_nft.maxSupply() == 100
    assert councillor_nft.getMerkleRoot() == new_merkle_root
