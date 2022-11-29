import pytest

from brownie import chain, reverts, LPVault, ERC20Mintable

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

    with reverts(revert_msg="cannot deposit zero _amount"):
        lp_vault.deposit(0, admin)

    with reverts(revert_msg="no delegation to 0"):
        lp_vault.deposit(0, "0x0000000000000000000000000000000000000000")

    token.approve(lp_vault, 10)
    lp_vault.deposit(10, admin)
    assert lp_vault.getRawVotingPower(admin) == lp_vault.getTotalRawVotingPower() == 10

    assert token.balanceOf(admin) == INITIAL_BALANCE - 10
    assert token.balanceOf(lp_vault) == 10


def test_delegation(admin, accounts, token, lp_vault):
    token.approve(lp_vault, 10)
    lp_vault.deposit(10, accounts[1])
    assert lp_vault.getTotalRawVotingPower() == 10
    assert lp_vault.getRawVotingPower(accounts[1]) == 10
    assert lp_vault.getRawVotingPower(admin) == 0

    tx = lp_vault.initiateWithdrawal(10, accounts[1])

    chain.sleep(DURATION_SECONDS)
    chain.mine()

    withdrawal_id = tx.events["WithdrawalQueued"]["id"]
    lp_vault.withdraw(withdrawal_id)
    assert lp_vault.getTotalRawVotingPower() == 0
    assert lp_vault.getRawVotingPower(accounts[1]) == 0
    assert lp_vault.getRawVotingPower(admin) == 0


def test_initiate_withdrawal(admin, token, lp_vault):
    token.approve(lp_vault, 10)
    lp_vault.deposit(10, admin)
    assert lp_vault.getRawVotingPower(admin) == 10

    lp_vault.initiateWithdrawal(10, admin)
    assert lp_vault.getRawVotingPower(admin) == 0

    with reverts(revert_msg="not enough delegated to unlock from _delegate"):
        lp_vault.initiateWithdrawal(10, admin)


def test_withdrawal(admin, token, lp_vault):
    token.approve(lp_vault, 10)
    lp_vault.deposit(10, admin)
    tx = lp_vault.initiateWithdrawal(10, admin)
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]

    with reverts(revert_msg="matching withdrawal does not exist"):
        lp_vault.withdraw(10)

    with reverts(revert_msg="no valid pending withdrawal"):
        lp_vault.withdraw(withdrawal_id)

    chain.sleep(DURATION_SECONDS)
    chain.mine()

    assert token.balanceOf(admin) == 90
    assert token.balanceOf(lp_vault) == 10
    lp_vault.withdraw(withdrawal_id)
    assert token.balanceOf(admin) == INITIAL_BALANCE
    assert token.balanceOf(lp_vault) == 0


def test_set_withdrawal_wait_duration(admin, accounts, token, lp_vault):
    lp_vault.setWithdrawalWaitDuration(0)

    token.approve(lp_vault, 10)
    lp_vault.deposit(10, admin)
    tx = lp_vault.initiateWithdrawal(10, admin)

    withdrawal_id = tx.events["WithdrawalQueued"]["id"]

    # no wait required
    lp_vault.withdraw(withdrawal_id)

    with reverts():
        tx = lp_vault.setWithdrawalWaitDuration(100, {"from": accounts[2]})


def test_withdrawal_id_increments(admin, token, lp_vault):
    token.approve(lp_vault, 10)
    lp_vault.deposit(10, admin)

    for i in range(10):
        tx = lp_vault.initiateWithdrawal(1, admin)
        withdrawal_id = tx.events["WithdrawalQueued"]["id"]
        assert i == withdrawal_id
