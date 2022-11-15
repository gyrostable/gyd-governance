import pytest

from brownie import chain, LPVault, ERC20Mintable
from brownie.exceptions import VirtualMachineError

DURATION_SECONDS = 60 * 60
INITIAL_BALANCE = 100


@pytest.fixture
def token(admin):
    c = admin.deploy(ERC20Mintable)
    c.mint(admin, INITIAL_BALANCE)
    return c


@pytest.fixture
def lp_vault(token, admin):
    return admin.deploy(LPVault, admin, token, DURATION_SECONDS)


def test_deposit(admin, token, lp_vault):
    assert lp_vault.getTotalRawVotingPower() == 0

    with pytest.raises(VirtualMachineError) as exc:
        lp_vault.deposit(0)
    assert "cannot deposit zero _amount" in str(exc.value)

    token.approve(lp_vault, 10)
    lp_vault.deposit(10)
    assert lp_vault.getRawVotingPower(admin) == lp_vault.getTotalRawVotingPower() == 10

    assert token.balanceOf(admin) == INITIAL_BALANCE - 10
    assert token.balanceOf(lp_vault) == 10


def test_initiate_withdrawal(admin, token, lp_vault):
    with pytest.raises(VirtualMachineError) as exc:
        lp_vault.initiateWithdrawal(10)
    assert "cannot unlock more than balance" in str(exc.value)

    token.approve(lp_vault, 10)
    lp_vault.deposit(10)
    assert lp_vault.getRawVotingPower(admin) == 10

    lp_vault.initiateWithdrawal(10)
    assert lp_vault.getRawVotingPower(admin) == 0

    lp_vault.initiateWithdrawal(8)
    assert lp_vault.getRawVotingPower(admin) == 2
    assert (
        lp_vault.getTotalRawVotingPower() == 10
    )  # Is this correct? Do fund queued for withdrawal count toward the total raw voting power?

    lp_vault.initiateWithdrawal(0)
    assert lp_vault.getRawVotingPower(admin) == 10


def test_withdrawal(admin, token, lp_vault):
    token.approve(lp_vault, 10)
    lp_vault.deposit(10)
    lp_vault.initiateWithdrawal(10)

    with pytest.raises(VirtualMachineError) as exc:
        lp_vault.withdraw()
    assert "no valid pending withdrawal" in str(exc.value)

    chain.sleep(DURATION_SECONDS)
    chain.mine()

    assert token.balanceOf(admin) == 90
    assert token.balanceOf(lp_vault) == 10
    lp_vault.withdraw()
    assert token.balanceOf(admin) == INITIAL_BALANCE
    assert token.balanceOf(lp_vault) == 0
