import pytest

from brownie import chain, reverts, LPVault
from brownie.exceptions import VirtualMachineError
from tests.conftest import INITIAL_BALANCE

DURATION_SECONDS = 60 * 60


@pytest.fixture
def lp_vault(token, admin, ERC20Mintable):
    reward_token = admin.deploy(ERC20Mintable)
    vault = admin.deploy(LPVault, admin, token, reward_token)
    vault.initialize(DURATION_SECONDS)
    return vault


def test_deposit(admin, token, lp_vault):
    assert lp_vault.getTotalRawVotingPower() == 0

    with reverts(revert_msg="cannot deposit zero _amount"):
        lp_vault.deposit(0, admin)

    with reverts(revert_msg="no delegation to 0"):
        lp_vault.deposit(0, "0x0000000000000000000000000000000000000000")

    token.approve(lp_vault, 10)
    lp_vault.deposit(10)
    assert lp_vault.getRawVotingPower(admin) == lp_vault.getTotalRawVotingPower() == 10

    assert token.balanceOf(admin) == INITIAL_BALANCE - 10
    assert token.balanceOf(lp_vault) == 10


def test_change_delegate(admin, accounts, token, lp_vault):
    assert lp_vault.getTotalRawVotingPower() == 0

    token.approve(lp_vault, 10)
    lp_vault.deposit(10, accounts[1], {"from": admin})
    assert (
        lp_vault.getRawVotingPower(accounts[1])
        == lp_vault.getTotalRawVotingPower()
        == 10
    )
    assert lp_vault.getDelegations(admin) == [(accounts[1], 10)]

    lp_vault.changeDelegate(accounts[1], accounts[2], 10)
    assert lp_vault.getRawVotingPower(accounts[2]) == 10
    assert lp_vault.getRawVotingPower(accounts[1]) == 0
    assert lp_vault.getDelegations(admin) == [(accounts[2], 10)]


def test_delegation(admin, accounts, token, lp_vault):
    token.approve(lp_vault, 10)
    lp_vault.deposit(10, accounts[1])
    assert lp_vault.getTotalRawVotingPower() == 10
    assert lp_vault.getRawVotingPower(accounts[1]) == 10
    assert lp_vault.getRawVotingPower(admin) == 0
    assert lp_vault.getDelegations(admin) == [(accounts[1], 10)]

    tx = lp_vault.initiateWithdrawal(10, accounts[1])
    assert lp_vault.getDelegations(admin) == []

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
    assert lp_vault.getTotalRawVotingPower() == 10
    assert lp_vault.getRawVotingPower(admin) == 10

    lp_vault.initiateWithdrawal(10, admin)
    assert lp_vault.getRawVotingPower(admin) == 0
    assert lp_vault.getTotalRawVotingPower() == 0

    with reverts(revert_msg="not enough to undelegate"):
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


def test_list_pending_withdrawals(admin, accounts, token, lp_vault):
    assert len(lp_vault.listPendingWithdrawals(accounts[2])) == 0

    token.approve(lp_vault, 20)
    lp_vault.deposit(20, admin)
    tx = lp_vault.initiateWithdrawal(10, admin)
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]

    pws = lp_vault.listPendingWithdrawals(admin)
    assert len(pws) == 1
    assert pws[0][0] == withdrawal_id

    tx = lp_vault.initiateWithdrawal(10, admin)
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]
    pws = lp_vault.listPendingWithdrawals(admin)
    assert len(pws) == 2
    assert pws[1][0] == withdrawal_id


def test_list_pending_withdrawals_doesnt_list_completed(
    admin, accounts, token, lp_vault
):
    assert len(lp_vault.listPendingWithdrawals(accounts[2])) == 0

    token.approve(lp_vault, 20)
    lp_vault.deposit(20, admin)
    tx = lp_vault.initiateWithdrawal(10, admin)
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]

    pws = lp_vault.listPendingWithdrawals(admin)
    assert len(pws) == 1
    assert pws[0][0] == withdrawal_id

    chain.sleep(DURATION_SECONDS)
    chain.mine()

    lp_vault.withdraw(withdrawal_id)

    pws = lp_vault.listPendingWithdrawals(admin)
    assert len(pws) == 0
