import pytest
from .conftest import ACCOUNT_ADDRESS, PROOF, signature
from brownie.exceptions import VirtualMachineError


def test_founding_frog_claim_nft(admin, accounts, frog_vault):
    # Vault has no claimed NFTS
    assert frog_vault.getRawVotingPower(admin) == 0
    # No NFTs means the user's voting power can't be updated
    with pytest.raises(VirtualMachineError) as exc:
        frog_vault.updateRawVotingPower([admin], 2)
    assert "all users must have at least 1 NFT" in str(exc.value)

    frog_vault.claimNFT(ACCOUNT_ADDRESS, PROOF, signature(frog_vault.address))
    assert frog_vault.getRawVotingPower(admin) == 1
    frog_vault.updateRawVotingPower([admin], 2)
    assert frog_vault.getRawVotingPower(admin) == 2
    assert frog_vault.getTotalRawVotingPower() == 6

    with pytest.raises(VirtualMachineError) as exc:
        frog_vault.claimNFT(
            ACCOUNT_ADDRESS, PROOF, signature(frog_vault.address), {"from": accounts[6]}
        )
    assert "NFT already claimed" in str(exc.value)
