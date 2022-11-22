import pytest
from brownie import ERC721Mintable, RecruitNFTVault, FoundingFrogVault, accounts
from brownie.exceptions import VirtualMachineError


@pytest.mark.parametrize("vault,", ["nft_vault", "frog_vault"], indirect=["vault"])
def test_total_raw_voting_power(vault):
    assert vault.getTotalRawVotingPower() == 5


@pytest.mark.parametrize("vault,", ["nft_vault", "frog_vault"], indirect=["vault"])
def test_raw_voting_power(vault, accounts):
    # no delegation means we just use the base voting power of the user
    assert vault.getRawVotingPower(accounts[0]) == 1

    # delegating to yourself doesn't result in double-counting
    vault.delegateVote(accounts[0], 1, {"from": accounts[0]})
    assert vault.getRawVotingPower(accounts[0]) == 1

    vault.undelegateVote(accounts[0], 1, {"from": accounts[0]})
    assert vault.getRawVotingPower(accounts[0]) == 1


@pytest.mark.parametrize("vault,", ["nft_vault", "frog_vault"], indirect=["vault"])
def test_delegation(vault, accounts):
    # first, delegate account[0]'s vote to account[5]
    vault.delegateVote(accounts[5], 1, {"from": accounts[0]})

    assert vault.getRawVotingPower(accounts[5]) == 1

    # next, try to delegate the same vote again. This should fail since
    # account[0] doesn't have that many to delegate.
    with pytest.raises(VirtualMachineError) as exc:
        vault.delegateVote(accounts[5], 1, {"from": accounts[0]})
    assert "insufficient balance to delegate" in str(exc.value)

    # try to delegate too many votes from accounts[1]
    with pytest.raises(VirtualMachineError) as exc:
        vault.delegateVote(accounts[1], 2, {"from": accounts[1]})
    assert "insufficient balance to delegate" in str(exc.value)


@pytest.mark.parametrize("vault,", ["nft_vault", "frog_vault"], indirect=["vault"])
def test_undelegation(vault, accounts):
    # first, undelegate account[0]'s vote to account[1];
    # This should fail since account[0] won't have delegated yet.
    with pytest.raises(VirtualMachineError) as exc:
        vault.undelegateVote(accounts[1], 1, {"from": accounts[0]})
    assert ("user has not delegated") in str(exc.value)

    # then, delegate account[0]'s vote to account[1]
    vault.delegateVote(accounts[1], 1, {"from": accounts[0]})

    # try to undelegate the wrong amount
    with pytest.raises(VirtualMachineError) as exc:
        vault.undelegateVote(accounts[1], 2, {"from": accounts[0]})
    assert ("partial undelegations not allowed") in str(exc.value)

    # try to undelegate from the wrong person
    with pytest.raises(VirtualMachineError) as exc:
        vault.undelegateVote(accounts[0], 1, {"from": accounts[0]})
    assert ("user has not delegated to _delegate") in str(exc.value)

    vault.undelegateVote(accounts[1], 1, {"from": accounts[0]})


@pytest.mark.parametrize("vault,", ["nft_vault", "frog_vault"], indirect=["vault"])
def test_update_raw_voting_power(vault, accounts):
    total = vault.getTotalRawVotingPower()

    vault.updateRawVotingPower([accounts[0]], 2)
    assert vault.getRawVotingPower(accounts[0]) == 2

    new_total = vault.getTotalRawVotingPower()
    assert new_total == total + 1

    vault.updateRawVotingPower([accounts[0]], 4)
    assert vault.getTotalRawVotingPower() == new_total + 2

    vault.delegateVote(accounts[1], 1, {"from": accounts[0]})
    assert vault.getRawVotingPower(accounts[0]) == 3

    with pytest.raises(VirtualMachineError) as exc:
        vault.updateRawVotingPower([accounts[0]], 1, {"from": accounts[0]})
    assert ("cannot decrease voting power") in str(exc.value)

    with pytest.raises(VirtualMachineError) as exc:
        vault.updateRawVotingPower([accounts[0]], 25, {"from": accounts[0]})
    assert ("voting power cannot be more than 20") in str(exc.value)

    with pytest.raises(VirtualMachineError) as exc:
        vault.updateRawVotingPower([accounts[0]], 0, {"from": accounts[0]})
    assert ("voting power cannot be less than 1") in str(exc.value)

    with pytest.raises(VirtualMachineError) as exc:
        vault.updateRawVotingPower([accounts[0], accounts[9]], 5, {"from": accounts[0]})
    assert ("all users must have at least 1 NFT") in str(exc.value)
