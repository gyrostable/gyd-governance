import pytest
from brownie import chain


@pytest.fixture
def voting_power_history(admin, VotingPowerHistoryLibrary):
    return admin.deploy(VotingPowerHistoryLibrary)


def test_voting_power_history(admin, voting_power_history):
    vph = voting_power_history
    tx = vph.updateVotingPower(admin, 1e18, 0e18, 0e18)
    assert vph.getVotingPower(admin, tx.timestamp) == 1e18

    tx = vph.updateVotingPower(admin, 1e18, 3e18, 1e18)
    assert vph.getVotingPower(admin, tx.timestamp) == 4e18

    tx = vph.updateVotingPower(admin, 0e18, 3e18, 1e18)
    assert vph.getVotingPower(admin, tx.timestamp) == 1e18


def test_binary_search(admin, voting_power_history):
    vph = voting_power_history
    tx1 = vph.updateVotingPower(admin, 1e18, 0e18, 0e18)

    # check the binary search when tx1.timestamp is at the boundary of a record
    assert vph.binarySearch(admin, tx1.timestamp) == (
        True,
        (tx1.timestamp, 1e18, 1e18, 0e18),  # multiplier is set to 1 if zero
    )

    # check when the record is before the timestamp
    assert vph.binarySearch(admin, tx1.timestamp + 10) == (
        True,
        (tx1.timestamp, 1e18, 1e18, 0e18),  # multiplier is set to 1 if zero
    )

    # check when the record is after the timestamp
    assert vph.binarySearch(admin, tx1.timestamp - 10) == (False, (0, 0, 1e18, 0))

    chain.sleep(2)
    tx2 = vph.updateVotingPower(admin, 2e18, 0e18, 0e18)

    # check when the timestamp is between tx1 and tx2
    assert vph.binarySearch(admin, tx1.timestamp + 1) == (
        True,
        (tx1.timestamp, 1e18, 1e18, 0e18),  # multiplier is set to 1 if zero
    )

    # check when the timestamp is after tx2
    assert vph.binarySearch(admin, tx2.timestamp + 10) == (
        True,
        (tx2.timestamp, 2e18, 1e18, 0e18),  # multiplier is set to 1 if zero
    )

    chain.sleep(2)
    tx3 = vph.updateVotingPower(admin, 3e18, 0e18, 0e18)
    # check when the timestamp is after tx3
    assert vph.binarySearch(admin, tx3.timestamp + 10) == (
        True,
        (tx3.timestamp, 3e18, 1e18, 0e18),  # multiplier is set to 1 if zero
    )

    # check when the timestamp is before tx1
    assert vph.binarySearch(admin, tx1.timestamp - 10) == (
        False,
        (0, 0e18, 1e18, 0e18),
    )

    # check when the timestamp is after tx1
    assert vph.binarySearch(admin, tx1.timestamp + 1) == (
        True,
        (tx1.timestamp, 1e18, 1e18, 0e18),
    )
