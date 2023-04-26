from brownie import reverts, chain
from eth_utils import keccak
from eth_abi.packed import encode_packed
from eip712.messages import EIP712Message


def test_recruit_nft_is_not_transferable(admin, accounts, recruit_nft, nft_vault):
    with reverts("cannot transfer NFT"):
        recruit_nft.transferFrom(admin, accounts[1], 0)


def test_recruit_nft_is_mintable_by_owner(admin, accounts, recruit_nft, nft_vault):
    acc = accounts[1]
    with reverts("ECDSA: invalid signature length"):
        recruit_nft.mint(acc, [], b"", {"from": acc})

    a = accounts.add()
    recruit_nft.mint(a, [], b"", {"from": admin})


def test_recruit_nft_supply_cap(admin, accounts, recruit_nft, nft_vault):
    # this brings the total of NFTs minted to the max supply
    for _ in range(recruit_nft.maxSupply() - recruit_nft.totalSupply()):
        a = accounts.add()
        recruit_nft.mint(a, [], b"", {"from": admin})

    assert recruit_nft.totalSupply() == recruit_nft.maxSupply()

    a = accounts.add()
    with reverts("mint error: supply cap would be exceeded"):
        recruit_nft.mint(a, [], b"", {"from": admin})


def signature(to, proof, verifying_contract):
    class Proof(EIP712Message):
        _name_: "string"
        _version_: "string"
        _chainId_: "uint256"
        _verifyingContract_: "address"

        to: "address"
        proof: "bytes32[]"

    proofB = [bytearray.fromhex(p[2:]) for p in proof]
    msg = Proof(
        _name_="RecruitNFT",
        _version_="1",
        _chainId_=chain.id,
        _verifyingContract_=verifying_contract,
        to=to.address,
        proof=proofB,
    )

    sm = to.sign_message(msg)
    return sm.signature.hex()


ROOT = "0xfcd11faacaee1c4654d0175b12a0a45870442d680639097d2f3baa754ba8be27"
PROOF = [
    "0xa96ba5eff69d2c1c3160cd10f130789fde827b071f22596664de70d4da817807",
    "0xa3f1aebd18f2581bae68275cb502db4b17b2490f841048a4fa2b41dbe3f75975",
]


def test_recruit_nft_is_mintable_by_allowlisted_address(
    admin, local_account, RecruitNFT, RecruitNFTVault
):
    recruit_nft = admin.deploy(RecruitNFT, "RecruitNFT", "RNFT", admin, 10, ROOT)
    nft_vault = admin.deploy(RecruitNFTVault, admin, recruit_nft)
    recruit_nft.setGovernanceVault(nft_vault.address)

    sig = signature(local_account, PROOF, recruit_nft.address)
    recruit_nft.mint(local_account, PROOF, sig, {"from": local_account})

    assert recruit_nft.balanceOf(local_account) == 1


def test_recruit_nft_is_mintable_only_once(
    admin, alice, bob, local_account, RecruitNFT, RecruitNFTVault
):
    recruit_nft = admin.deploy(RecruitNFT, "RecruitNFT", "RNFT", admin, 10, ROOT)
    nft_vault = admin.deploy(RecruitNFTVault, admin, recruit_nft)
    recruit_nft.setGovernanceVault(nft_vault.address)

    sig = signature(local_account, PROOF, recruit_nft.address)
    recruit_nft.mint(local_account, PROOF, sig, {"from": local_account})

    with reverts("user has already claimed NFT"):
        recruit_nft.mint(local_account, PROOF, sig, {"from": alice})

    with reverts("user has already claimed NFT"):
        recruit_nft.mint(local_account, PROOF, sig, {"from": bob})
