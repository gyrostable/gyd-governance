import pytest

from tests.support.utils import scale


@pytest.fixture(scope="module")
def lm(SampleLiquidityMining, token, admin):
    return admin.deploy(SampleLiquidityMining, token)


@pytest.fixture(scope="module")
def reward_token(interface, lm):
    return interface.ERC20(lm.rewardToken())


@pytest.fixture(scope="module", autouse=True)
def mint_token_to_alice_and_bob(token, alice, bob, admin):
    token.mint(alice, scale(1000), {"from": admin})
    token.mint(bob, scale(1000), {"from": admin})


@pytest.fixture(scope="module", autouse=True)
def approve_deposit(lm, token, alice, bob):
    token.approve(lm, scale(1000), {"from": alice})
    token.approve(lm, scale(1000), {"from": bob})


def test_stake(lm, alice, bob):
    alice_deposit_amount = scale(100)
    lm.deposit(alice_deposit_amount, {"from": alice})
    assert lm.stakedBalanceOf(alice) == alice_deposit_amount
    assert lm.totalStaked() == alice_deposit_amount

    bob_deposit_amount = scale(50)
    lm.deposit(bob_deposit_amount, {"from": bob})
    assert lm.stakedBalanceOf(alice) == alice_deposit_amount
    assert lm.stakedBalanceOf(bob) == bob_deposit_amount
    assert lm.totalStaked() == alice_deposit_amount + bob_deposit_amount


def test_unstake(lm, alice, bob):
    lm.deposit(scale(100), {"from": alice})
    lm.deposit(scale(50), {"from": bob})
    lm.withdraw(scale(20), {"from": bob})
    assert lm.stakedBalanceOf(bob) == scale(30)
    assert lm.totalStaked() == scale(130)
    lm.withdraw(scale(60), {"from": alice})

    assert lm.stakedBalanceOf(alice) == scale(40)
    assert lm.stakedBalanceOf(bob) == scale(30)
    assert lm.totalStaked() == scale(70)


def _claim_and_check_rewards(lm, reward_token, account, expected):
    balance_before = int(reward_token.balanceOf(account))
    tx = lm.claimRewards({"from": account})
    balance_increase = int(reward_token.balanceOf(account)) - balance_before
    assert tx.events["Claim"][0]["beneficiary"] == account
    amount_claimed = int(tx.events["Claim"][0]["amount"])
    assert amount_claimed == pytest.approx(expected)
    assert balance_increase == pytest.approx(expected)


def test_rewards_computation(lm, alice, bob, chain, reward_token):
    tx = lm.deposit(scale(6), {"from": alice})
    tx = lm.deposit(scale(3), {"from": bob})
    deposit_time = tx.timestamp

    chain.sleep(7 * 86400)
    chain.mine()

    time_elapsed = chain[-1]["timestamp"] - deposit_time
    compute_expected = lambda v: v / 9 * time_elapsed * lm.rewardsEmissionRate()
    alice_expected = compute_expected(6)
    bob_expected = compute_expected(3)

    assert int(lm.claimableRewards(alice)) == pytest.approx(alice_expected)
    assert int(lm.claimableRewards(bob)) == pytest.approx(bob_expected)
    lm.withdraw(scale(5), {"from": alice})

    _claim_and_check_rewards(lm, reward_token, alice, alice_expected)
    _claim_and_check_rewards(lm, reward_token, bob, bob_expected)
