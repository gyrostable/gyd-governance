import pytest

from brownie import chain, reverts, AggregateLPVault, MockVault

INITIAL_RAW_VOTING_POWER = 10
INITIAL_TOTAL_RAW_VOTING_POWER = 100
INITIAL_THRESHOLD = 2000


@pytest.fixture(scope="module")
def aggregate_lp_vault(admin, voting_power_aggregator):
    return admin.deploy(AggregateLPVault, admin, INITIAL_THRESHOLD)


def test_aggregate_lp_vault_scaled_threshold(admin, aggregate_lp_vault, alice):
    mv = admin.deploy(MockVault)
    mv.updateVotingPower(admin, INITIAL_RAW_VOTING_POWER)
    mv.updateVotingPower(
        alice, INITIAL_TOTAL_RAW_VOTING_POWER - INITIAL_RAW_VOTING_POWER
    )
    mv2 = admin.deploy(MockVault)
    mv2.updateVotingPower(alice, INITIAL_TOTAL_RAW_VOTING_POWER)

    aggregate_lp_vault.setVaultWeights(
        [
            (mv, 1 * 1e18),
            (mv2, 2 * 1e18),
        ]
    )
    assert aggregate_lp_vault.getRawVotingPower(admin) == 10
    assert aggregate_lp_vault.getTotalRawVotingPower() == 2000

    aggregate_lp_vault.setThreshold(5)
    assert aggregate_lp_vault.getRawVotingPower(admin) == 10
    assert aggregate_lp_vault.getTotalRawVotingPower() == 300

    aggregate_lp_vault.setVaultWeights(
        [
            (mv, 2 * 1e18),
            (mv2, 1 * 1e18),
        ]
    )
    assert aggregate_lp_vault.getRawVotingPower(admin) == 20
    assert aggregate_lp_vault.getTotalRawVotingPower() == 300
