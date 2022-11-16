import pytest

from brownie import chain, reverts, AggregateLPVault, MockVault
from brownie.exceptions import VirtualMachineError

INITIAL_RAW_VOTING_POWER = 10
INITIAL_TOTAL_RAW_VOTING_POWER = 100
INITIAL_THRESHOLD = 2000


@pytest.fixture
def mock_vault(admin):
    return admin.deploy(
        MockVault, INITIAL_RAW_VOTING_POWER, INITIAL_TOTAL_RAW_VOTING_POWER
    )


@pytest.fixture()
def aggregate_lp_vault(admin, mock_vault):
    return admin.deploy(AggregateLPVault, admin, INITIAL_THRESHOLD)


def test_aggregate_lp_vault_scaled_threshold(admin, mock_vault, aggregate_lp_vault):
    mv = admin.deploy(MockVault, 10, 100)
    mv2 = admin.deploy(MockVault, 0, 100)

    aggregate_lp_vault.setVaultPrices(
        [
            (mv, 1),
            (mv2, 2),
        ]
    )
    assert aggregate_lp_vault.getRawVotingPower(admin) == 10
    assert aggregate_lp_vault.getTotalRawVotingPower() == 2000

    aggregate_lp_vault.setThreshold(5)
    assert aggregate_lp_vault.getRawVotingPower(admin) == 10
    assert aggregate_lp_vault.getTotalRawVotingPower() == 300

    aggregate_lp_vault.setVaultPrices(
        [
            (mv, 2),
            (mv2, 1),
        ]
    )
    assert aggregate_lp_vault.getRawVotingPower(admin) == 20
    assert aggregate_lp_vault.getTotalRawVotingPower() == 300
