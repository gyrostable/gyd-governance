import pytest
from .conftest import ACCOUNT_ADDRESS, ACCOUNT_KEY, PROOF, ROOT, signature
from brownie import reverts, chain


def test_user_owns_no_nft(admin, accounts, frog_vault):
    # Vault has no claimed NFTS
    assert frog_vault.getRawVotingPower(admin) == 0
    # No NFTs means the user's voting power can't be updated
    with reverts("all users must have at least 1 NFT"):
        frog_vault.updateMultiplier([admin], 2e18)


def test_invalid_proof_claim(admin, local_account, accounts, frog_vault):
    # Attempt to claim with an invalid proof, namely the root.
    # This will get hashed with the ACCOUNT_ADDRESS to produce
    # a new, different root.
    with reverts("invalid proof"):
        frog_vault.claimNFT(
            ACCOUNT_ADDRESS,
            1e18,
            [ROOT],
            signature(local_account, 1e18, frog_vault.address, [ROOT]),
        )


def test_valid_proof(admin, accounts, frog_vault, local_account):
    frog_vault.claimNFT(
        ACCOUNT_ADDRESS,
        1e18,
        PROOF,
        signature(local_account, 1e18, frog_vault.address, PROOF),
    )
    assert frog_vault.getRawVotingPower(admin) == 1e18
    frog_vault.updateMultiplier([admin], 2e18)
    assert frog_vault.getRawVotingPower(admin) == 2e18
    assert frog_vault.getTotalRawVotingPower() == 6e18


def test_claiming_nft_doesnt_increase_supply(
    local_account, admin, accounts, frog_vault
):
    assert frog_vault.getTotalRawVotingPower() == 5e18
    frog_vault.claimNFT(
        ACCOUNT_ADDRESS,
        1e18,
        PROOF,
        signature(local_account, 1e18, frog_vault.address, PROOF),
    )
    assert frog_vault.getTotalRawVotingPower() == 5e18

    frog_vault.updateMultiplier([admin], 5e18)
    # Supply increases by multiplier - 1 since the base value (1) is included in the
    # supply
    assert frog_vault.getTotalRawVotingPower() == 9e18


def test_updates_raw_power(local_account, admin, accounts, frog_vault):
    frog_vault.claimNFT(
        ACCOUNT_ADDRESS,
        1e18,
        PROOF,
        signature(local_account, 1e18, frog_vault.address, PROOF),
    )
    assert frog_vault.getRawVotingPower(admin) == 1e18
    assert frog_vault.getTotalRawVotingPower() == 5e18

    frog_vault.updateMultiplier([admin], 2e18)
    assert frog_vault.getRawVotingPower(admin) == 2e18
    assert frog_vault.getTotalRawVotingPower() == 6e18


def test_nft_already_claimed(local_account, admin, accounts, frog_vault):
    frog_vault.claimNFT(
        ACCOUNT_ADDRESS,
        1e18,
        PROOF,
        signature(local_account, 1e18, frog_vault.address, PROOF),
        {"from": accounts[6]},
    )
    with reverts("NFT already claimed"):
        frog_vault.claimNFT(
            ACCOUNT_ADDRESS,
            1e18,
            PROOF,
            signature(local_account, 1e18, frog_vault.address, PROOF),
            {"from": accounts[6]},
        )


def test_nft_claimed_with_nonzero_multiplier(admin, local_account, FoundingFrogVault):
    root = "0x8005654da8bad4ccb60009614a4f7d79bdb27f747c64fef259f5b7a0f064bc5a"
    proof = [
        "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
        "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
        "0xcc20bdebe234641ec9c9c1c278579ef608f23fb46f1be71cd61a8cb3d6a53735",
    ]
    multiplier = 2e18
    frog_vault = admin.deploy(FoundingFrogVault, admin, 6e18, root)
    frog_vault.claimNFT(
        ACCOUNT_ADDRESS,
        multiplier,
        proof,
        signature(local_account, multiplier, frog_vault.address, proof),
        {"from": admin},
    )
    assert frog_vault.getRawVotingPower(admin) == 2e18
    assert frog_vault.getTotalRawVotingPower() == 6e18
