import pytest
from brownie import ERC721Mintable, NFTVault, accounts
from brownie.exceptions import VirtualMachineError


@pytest.fixture
def nft(ERC721Mintable, accounts):
    contract = accounts[0].deploy(ERC721Mintable)
    for i in range(5):
        contract.mint(accounts[i], i)

    return contract


@pytest.fixture
def nft_vault(nft, accounts):
    return accounts[0].deploy(NFTVault, nft)


@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


def test_total_raw_voting_power(nft_vault):
    assert nft_vault.totalRawVotingPower() == 5


def test_raw_voting_power(nft_vault, accounts):
    assert nft_vault.rawVotingPower(accounts[0]) == 0

    nft_vault.delegateVote(accounts[0], 1, {"from": accounts[0]})
    assert nft_vault.rawVotingPower(accounts[0]) == 1

    nft_vault.undelegateVote(accounts[0], 1, {"from": accounts[0]})
    assert nft_vault.rawVotingPower(accounts[0]) == 0


def test_delegation(nft_vault, accounts):
    # first, delegate account[0]'s vote to account[1]
    nft_vault.delegateVote(accounts[1], 1, {"from": accounts[0]})

    assert nft_vault.rawVotingPower(accounts[1]) == 1

    # next, try to delegate the same vote again. This should fail since
    # account[0] doesn't have that many to delegate.
    with pytest.raises(VirtualMachineError) as exc:
        nft_vault.delegateVote(accounts[1], 1, {"from": accounts[0]})
    assert "insufficient balance to delegate" in str(exc.value)

    # try to delegate too many votes from accounts[1]
    with pytest.raises(VirtualMachineError) as exc:
        nft_vault.delegateVote(accounts[1], 2, {"from": accounts[1]})
    assert "insufficient balance to delegate" in str(exc.value)


def test_undelegation(nft_vault):
    # first, undelegate account[0]'s vote to account[1];
    # This should fail since account[0] won't have delegated yet.
    with pytest.raises(VirtualMachineError) as exc:
        nft_vault.undelegateVote(accounts[1], 1, {"from": accounts[0]})
    assert ("user has not delegated") in str(exc.value)

    # then, delegate account[0]'s vote to account[1]
    nft_vault.delegateVote(accounts[1], 1, {"from": accounts[0]})

    # try to undelegate the wrong amount
    with pytest.raises(VirtualMachineError) as exc:
        nft_vault.undelegateVote(accounts[1], 2, {"from": accounts[0]})
    assert ("partial undelegations not allowed") in str(exc.value)

    # try to undelegate from the wrong person
    with pytest.raises(VirtualMachineError) as exc:
        nft_vault.undelegateVote(accounts[0], 1, {"from": accounts[0]})
    assert ("user has not delegated to _delegate") in str(exc.value)

    nft_vault.undelegateVote(accounts[1], 1, {"from": accounts[0]})
