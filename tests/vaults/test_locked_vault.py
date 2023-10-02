import pytest

from brownie import ZERO_ADDRESS, chain, reverts, LockedVault
from brownie.exceptions import VirtualMachineError
from tests.conftest import INITIAL_BALANCE

DURATION_SECONDS = 60 * 60


@pytest.fixture
def locked_vault(token, admin, ERC20Mintable):
    reward_token = admin.deploy(ERC20Mintable)
    vault = admin.deploy(LockedVault, admin, token, reward_token)
    vault.initialize(DURATION_SECONDS)
    return vault


@pytest.fixture
def locked_vault_6_decimals(token, admin, ERC20Mintable):
    token.changeDecimals(6)
    reward_token = admin.deploy(ERC20Mintable)
    vault = admin.deploy(LockedVault, admin, token, reward_token)
    vault.initialize(DURATION_SECONDS)
    return vault


def test_deposit(admin, token, locked_vault):
    assert locked_vault.getTotalRawVotingPower() == 0

    with reverts(revert_msg="cannot deposit zero amount"):
        locked_vault.deposit(0, admin)

    with reverts(revert_msg="no delegation to 0"):
        locked_vault.deposit(0, "0x0000000000000000000000000000000000000000")

    token.approve(locked_vault, 10)
    locked_vault.deposit(10)
    assert (
        locked_vault.getRawVotingPower(admin)
        == locked_vault.getTotalRawVotingPower()
        == 10
    )

    assert token.balanceOf(admin) == INITIAL_BALANCE - 10
    assert token.balanceOf(locked_vault) == 10


def test_change_delegate(admin, accounts, token, locked_vault):
    assert locked_vault.getTotalRawVotingPower() == 0

    token.approve(locked_vault, 10)
    locked_vault.deposit(10, accounts[1], {"from": admin})
    assert (
        locked_vault.getRawVotingPower(accounts[1])
        == locked_vault.getTotalRawVotingPower()
        == 10
    )
    assert locked_vault.getDelegations(admin) == [(accounts[1], 10)]

    locked_vault.changeDelegate(accounts[1], accounts[2], 10)
    assert locked_vault.getRawVotingPower(accounts[2]) == 10
    assert locked_vault.getRawVotingPower(accounts[1]) == 0
    assert locked_vault.getDelegations(admin) == [(accounts[2], 10)]


def test_delegation(admin, accounts, token, locked_vault):
    token.approve(locked_vault, 10)
    locked_vault.deposit(10, accounts[1])
    assert locked_vault.getTotalRawVotingPower() == 10
    assert locked_vault.getRawVotingPower(accounts[1]) == 10
    assert locked_vault.getRawVotingPower(admin) == 0
    assert locked_vault.getDelegations(admin) == [(accounts[1], 10)]

    tx = locked_vault.initiateWithdrawal(10, accounts[1])
    assert locked_vault.getDelegations(admin) == []

    chain.sleep(DURATION_SECONDS)
    chain.mine()

    withdrawal_id = tx.events["WithdrawalQueued"]["id"]
    locked_vault.withdraw(withdrawal_id)
    assert locked_vault.getTotalRawVotingPower() == 0
    assert locked_vault.getRawVotingPower(accounts[1]) == 0
    assert locked_vault.getRawVotingPower(admin) == 0


def test_initiate_withdrawal(admin, token, locked_vault):
    token.approve(locked_vault, 10)
    locked_vault.deposit(10, admin)
    assert locked_vault.getTotalRawVotingPower() == 10
    assert locked_vault.getRawVotingPower(admin) == 10

    locked_vault.initiateWithdrawal(10, admin)
    assert locked_vault.getRawVotingPower(admin) == 0
    assert locked_vault.getTotalRawVotingPower() == 0

    with reverts(revert_msg="not enough to undelegate"):
        locked_vault.initiateWithdrawal(10, admin)


def test_withdrawal(admin, token, locked_vault):
    token.approve(locked_vault, 10)
    locked_vault.deposit(10, admin)
    tx = locked_vault.initiateWithdrawal(10, admin)
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]

    with reverts(revert_msg="matching withdrawal does not exist"):
        locked_vault.withdraw(10)

    with reverts(revert_msg="no valid pending withdrawal"):
        locked_vault.withdraw(withdrawal_id)

    chain.sleep(DURATION_SECONDS)
    chain.mine()

    assert token.balanceOf(admin) == 90
    assert token.balanceOf(locked_vault) == 10
    locked_vault.withdraw(withdrawal_id)
    assert token.balanceOf(admin) == INITIAL_BALANCE
    assert token.balanceOf(locked_vault) == 0


def test_set_withdrawal_wait_duration(admin, accounts, token, locked_vault):
    locked_vault.setWithdrawalWaitDuration(0)

    token.approve(locked_vault, 10)
    locked_vault.deposit(10, admin)
    tx = locked_vault.initiateWithdrawal(10, admin)

    withdrawal_id = tx.events["WithdrawalQueued"]["id"]

    # no wait required
    locked_vault.withdraw(withdrawal_id)

    with reverts():
        tx = locked_vault.setWithdrawalWaitDuration(100, {"from": accounts[2]})


def test_withdrawal_id_increments(admin, token, locked_vault):
    token.approve(locked_vault, 10)
    locked_vault.deposit(10, admin)

    for i in range(10):
        tx = locked_vault.initiateWithdrawal(1, admin)
        withdrawal_id = tx.events["WithdrawalQueued"]["id"]
        assert i == withdrawal_id


def test_list_pending_withdrawals(admin, accounts, token, locked_vault):
    assert len(locked_vault.listPendingWithdrawals(accounts[2])) == 0

    token.approve(locked_vault, 20)
    locked_vault.deposit(20, admin)
    tx = locked_vault.initiateWithdrawal(10, admin)
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]

    pws = locked_vault.listPendingWithdrawals(admin)
    assert len(pws) == 1
    assert pws[0][0] == withdrawal_id

    tx = locked_vault.initiateWithdrawal(10, admin)
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]
    pws = locked_vault.listPendingWithdrawals(admin)
    assert len(pws) == 2
    assert pws[1][0] == withdrawal_id


def test_list_pending_withdrawals_doesnt_list_completed(
    admin, accounts, token, locked_vault
):
    assert len(locked_vault.listPendingWithdrawals(accounts[2])) == 0

    token.approve(locked_vault, 20)
    locked_vault.deposit(20, admin)
    tx = locked_vault.initiateWithdrawal(10, admin)
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]

    pws = locked_vault.listPendingWithdrawals(admin)
    assert len(pws) == 1
    assert pws[0][0] == withdrawal_id

    chain.sleep(DURATION_SECONDS)
    chain.mine()

    locked_vault.withdraw(withdrawal_id)

    pws = locked_vault.listPendingWithdrawals(admin)
    assert len(pws) == 0


def test_cannot_abuse_delegation(locked_vault, admin, token, alice):
    token.approve(locked_vault, 10)
    locked_vault.deposit(10, alice)
    assert (
        locked_vault.getRawVotingPower(alice)
        == locked_vault.getTotalRawVotingPower()
        == 10
    )
    with reverts("not enough to undelegate"):
        locked_vault.initiateWithdrawal(10, ZERO_ADDRESS)


def test_withdrawal_custom_decimals(admin, token, locked_vault_6_decimals):
    locked_vault = locked_vault_6_decimals

    token.mint(admin, 10**6)
    token.approve(locked_vault, 10**6)
    locked_vault.deposit(10**6, admin)
    assert locked_vault.getRawVotingPower(admin) == 10**18
    assert locked_vault.getTotalRawVotingPower() == 10**18

    tx = locked_vault.initiateWithdrawal(10**18, admin)
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]
    assert tx.events["WithdrawalQueued"]["amount"] == 10**18

    chain.sleep(DURATION_SECONDS)
    chain.mine()

    current_balance = token.balanceOf(admin)
    locked_vault.withdraw(withdrawal_id)
    assert token.balanceOf(admin) == current_balance + 10**6
    assert token.balanceOf(locked_vault) == 0
    assert locked_vault.getRawVotingPower(admin) == 0
    assert locked_vault.getTotalRawVotingPower() == 0
