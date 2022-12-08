import pytest
from brownie import (
    ERC721Mintable,
    RecruitNFTVault,
    FoundingFrogVault,
    accounts,
    reverts,
)


def test_total_raw_voting_power(vault):
    assert vault.getTotalRawVotingPower() == 5


def test_raw_voting_power(vault, admin):
    # no delegation means we just use the base voting power of the user
    assert vault.getRawVotingPower(admin) == 1


def test_no_double_counting_from_self_delegation(vault, admin):
    vault.delegateVote(admin, 1, {"from": admin})
    assert vault.getRawVotingPower(admin) == 1

    vault.undelegateVote(admin, 1, {"from": admin})
    assert vault.getRawVotingPower(admin) == 1


def test_delegation(vault, admin, accounts):
    vault.delegateVote(accounts[5], 1, {"from": admin})
    assert vault.getRawVotingPower(accounts[5]) == 1


def test_no_double_delegation(vault, admin, accounts):
    vault.delegateVote(accounts[5], 1, {"from": admin})
    # next, try to delegate the same vote again. This should fail since
    # account[0] doesn't have that many to delegate.
    with reverts("insufficient balance to delegate"):
        vault.delegateVote(accounts[5], 1, {"from": admin})


def test_no_excess_delegation(vault, admin, accounts):
    # try to delegate too many votes from accounts[1]
    with reverts("insufficient balance to delegate"):
        vault.delegateVote(accounts[1], 2, {"from": accounts[1]})


def test_no_onward_delegation(vault, admin, accounts):
    assert vault.getRawVotingPower(accounts[5]) == 0

    # first, delegate account[0]'s vote to account[5]
    vault.delegateVote(accounts[5], 1, {"from": admin})
    assert vault.getRawVotingPower(accounts[5]) == 1

    with reverts("insufficient balance to delegate"):
        vault.delegateVote(accounts[6], 1, {"from": accounts[5]})


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


def test_undelegation(vault, admin, accounts):
    # first, undelegate account[0]'s vote to account[1];
    # This should fail since account[0] won't have delegated yet.
    with reverts("user has not delegated enough to _delegate"):
        vault.undelegateVote(accounts[1], 1, {"from": admin})

    # then, delegate account[0]'s vote to account[1]
    vault.delegateVote(accounts[1], 1, {"from": admin})

    # try to undelegate the wrong amount
    with reverts("user has not delegated enough to _delegate"):
        vault.undelegateVote(accounts[1], 2, {"from": admin})

    # try to undelegate from the wrong person
    with reverts("user has not delegated enough to _delegate"):
        vault.undelegateVote(admin, 1, {"from": admin})

    vault.undelegateVote(accounts[1], 1, {"from": admin})


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


def test_raw_voting_power_cannot_decrease(vault, admin):
    with reverts("cannot decrease voting power"):
        vault.updateRawVotingPower([admin], 1, {"from": admin})


def test_limit_on_raw_voting_power(vault, admin):
    with reverts("voting power cannot be more than 20"):
        vault.updateRawVotingPower([admin], 25, {"from": admin})


def test_raw_voting_power_cannot_be_zeroed(vault, admin):
    with reverts("voting power cannot be less than 1"):
        vault.updateRawVotingPower([admin], 0, {"from": admin})


def test_all_users_must_have_voting_power_to_update(vault, admin):
    with reverts("all users must have at least 1 NFT"):
        vault.updateRawVotingPower([admin, accounts[9]], 5, {"from": admin})
