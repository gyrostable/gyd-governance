import pytest
from brownie import ERC721Mintable, RecruitNFTVault, FoundingFrogVault, accounts
from brownie.exceptions import VirtualMachineError


@pytest.mark.parametrize("vault,", ["nft_vault", "frog_vault"], indirect=["vault"])
def test_total_raw_voting_power(vault):
    assert vault.getTotalRawVotingPower() == 5


@pytest.mark.parametrize("vault,", ["nft_vault", "frog_vault"], indirect=["vault"])
def test_raw_voting_power(vault, admin):
    # no delegation means we just use the base voting power of the user
    assert vault.getRawVotingPower(admin) == 1

    # delegating to yourself doesn't result in double-counting
    vault.delegateVote(admin, 1, {"from": admin})
    assert vault.getRawVotingPower(admin) == 1

    vault.undelegateVote(admin, 1, {"from": admin})
    assert vault.getRawVotingPower(admin) == 1


@pytest.mark.parametrize("vault,", ["nft_vault", "frog_vault"], indirect=["vault"])
def test_delegation(vault, admin, accounts):
    # first, delegate account[0]'s vote to account[5]
    vault.delegateVote(accounts[5], 1, {"from": admin})

    assert vault.getRawVotingPower(accounts[5]) == 1

    # next, try to delegate the same vote again. This should fail since
    # account[0] doesn't have that many to delegate.
    with pytest.raises(VirtualMachineError) as exc:
        vault.delegateVote(accounts[5], 1, {"from": admin})
    assert "insufficient balance to delegate" in str(exc.value)

    # try to delegate too many votes from accounts[1]
    with pytest.raises(VirtualMachineError) as exc:
        vault.delegateVote(accounts[1], 2, {"from": accounts[1]})
    assert "insufficient balance to delegate" in str(exc.value)


@pytest.mark.parametrize("vault,", ["nft_vault", "frog_vault"], indirect=["vault"])
def test_no_onward_delegation(vault, admin, accounts):
    assert vault.getRawVotingPower(accounts[5]) == 0

    # first, delegate account[0]'s vote to account[5]
    vault.delegateVote(accounts[5], 1, {"from": admin})
    assert vault.getRawVotingPower(accounts[5]) == 1

    with pytest.raises(VirtualMachineError) as exc:
        vault.delegateVote(accounts[6], 1, {"from": accounts[5]})
    assert "insufficient balance to delegate" in str(exc.value)


@pytest.mark.parametrize("vault,", ["nft_vault", "frog_vault"], indirect=["vault"])
def test_delegation_with_mutable_voting_power(vault, admin, accounts):
    vault.delegateVote(accounts[5], 1, {"from": admin})
    assert vault.getRawVotingPower(admin) == 0
    assert vault.getRawVotingPower(accounts[5]) == 1

    vault.updateRawVotingPower([admin], 2)
    assert vault.getRawVotingPower(admin) == 1

    vault.delegateVote(accounts[6], 1, {"from": admin})
    assert vault.getRawVotingPower(accounts[6]) == 1

    vault.undelegateVote(accounts[6], 1, {"from": admin})
    vault.delegateVote(accounts[5], 1, {"from": admin})
    assert vault.getRawVotingPower(accounts[5]) == 2
    assert vault.getRawVotingPower(accounts[6]) == 0
    assert vault.getRawVotingPower(admin) == 0


@pytest.mark.parametrize("vault,", ["nft_vault", "frog_vault"], indirect=["vault"])
def test_undelegation(vault, admin, accounts):
    # first, undelegate account[0]'s vote to account[1];
    # This should fail since account[0] won't have delegated yet.
    with pytest.raises(VirtualMachineError) as exc:
        vault.undelegateVote(accounts[1], 1, {"from": admin})
    assert ("user has not delegated") in str(exc.value)

    # then, delegate account[0]'s vote to account[1]
    vault.delegateVote(accounts[1], 1, {"from": admin})

    # try to undelegate the wrong amount
    with pytest.raises(VirtualMachineError) as exc:
        vault.undelegateVote(accounts[1], 2, {"from": admin})
    assert ("user has not delegated enough to _delegate") in str(exc.value)

    # try to undelegate from the wrong person
    with pytest.raises(VirtualMachineError) as exc:
        vault.undelegateVote(admin, 1, {"from": admin})
    assert ("user has not delegated enough to _delegate") in str(exc.value)

    vault.undelegateVote(accounts[1], 1, {"from": admin})


@pytest.mark.parametrize("vault,", ["nft_vault", "frog_vault"], indirect=["vault"])
def test_update_raw_voting_power(vault, admin, accounts):
    total = vault.getTotalRawVotingPower()

    vault.updateRawVotingPower([admin], 2)
    assert vault.getRawVotingPower(admin) == 2

    new_total = vault.getTotalRawVotingPower()
    assert new_total == total + 1

    vault.updateRawVotingPower([admin], 4)
    assert vault.getTotalRawVotingPower() == new_total + 2

    vault.delegateVote(accounts[1], 1, {"from": admin})
    assert vault.getRawVotingPower(admin) == 3

    with pytest.raises(VirtualMachineError) as exc:
        vault.updateRawVotingPower([admin], 1, {"from": admin})
    assert ("cannot decrease voting power") in str(exc.value)

    with pytest.raises(VirtualMachineError) as exc:
        vault.updateRawVotingPower([admin], 25, {"from": admin})
    assert ("voting power cannot be more than 20") in str(exc.value)

    with pytest.raises(VirtualMachineError) as exc:
        vault.updateRawVotingPower([admin], 0, {"from": admin})
    assert ("voting power cannot be less than 1") in str(exc.value)

    with pytest.raises(VirtualMachineError) as exc:
        vault.updateRawVotingPower([admin, accounts[9]], 5, {"from": admin})
    assert ("all users must have at least 1 NFT") in str(exc.value)
