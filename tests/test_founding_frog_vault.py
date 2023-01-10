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
            [ROOT],
            signature(local_account, frog_vault.address, [ROOT]),
        )


def test_valid_proof(admin, accounts, frog_vault, local_account):
    frog_vault.claimNFT(
        ACCOUNT_ADDRESS, PROOF, signature(local_account, frog_vault.address, PROOF)
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
        ACCOUNT_ADDRESS, PROOF, signature(local_account, frog_vault.address, PROOF)
    )
    assert frog_vault.getTotalRawVotingPower() == 5e18

    frog_vault.updateMultiplier([admin], 5e18)
    # Supply increases by multiplier - 1 since the base value (1) is included in the
    # supply
    assert frog_vault.getTotalRawVotingPower() == 9e18


def test_updates_raw_power(local_account, admin, accounts, frog_vault):
    frog_vault.claimNFT(
        ACCOUNT_ADDRESS, PROOF, signature(local_account, frog_vault.address, PROOF)
    )
    assert frog_vault.getRawVotingPower(admin) == 1e18
    assert frog_vault.getTotalRawVotingPower() == 5e18

    frog_vault.updateMultiplier([admin], 2e18)
    assert frog_vault.getRawVotingPower(admin) == 2e18
    assert frog_vault.getTotalRawVotingPower() == 6e18


def test_nft_already_claimed(local_account, admin, accounts, frog_vault):
    frog_vault.claimNFT(
        ACCOUNT_ADDRESS,
        PROOF,
        signature(local_account, frog_vault.address, PROOF),
        {"from": accounts[6]},
    )
    with reverts("NFT already claimed"):
        frog_vault.claimNFT(
            ACCOUNT_ADDRESS,
            PROOF,
            signature(local_account, frog_vault.address, PROOF),
            {"from": accounts[6]},
        )
