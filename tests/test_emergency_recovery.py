import pytest
from brownie import (
    EmergencyRecovery,
    MockProxy,
    MockVotingPowerAggregator,
    accounts,
    chain,
    reverts,
)

SUNSET_DURATION = 10 * 60 * 60  # 10 hours
TIMELOCK_DURATION = 60 * 60  # 1 hour
VETO_THRESHOLD = 2e17  # 0.2


@pytest.fixture()
def mock_voting_aggregator(admin):
    return admin.deploy(MockVotingPowerAggregator, 21e18, 100e18, 21e16)


@pytest.fixture()
def mock_proxy(admin):
    return admin.deploy(MockProxy)


@pytest.fixture()
def emergency_recovery(admin, mock_proxy, mock_voting_aggregator):
    return admin.deploy(
        EmergencyRecovery,
        mock_proxy,
        admin.address,
        mock_voting_aggregator,
        chain.time() + SUNSET_DURATION,
        VETO_THRESHOLD,
        TIMELOCK_DURATION,
    )


@pytest.fixture()
def emergency_recovery_with_admin_governance(admin, mock_voting_aggregator):
    return admin.deploy(
        EmergencyRecovery,
        admin.address,
        admin.address,
        mock_voting_aggregator,
        chain.time() + SUNSET_DURATION,
        VETO_THRESHOLD,
        TIMELOCK_DURATION,
    )


def test_can_carry_out_emergency_upgrade(emergency_recovery, mock_proxy):
    toAddress = accounts[1]
    tx = emergency_recovery.startGovernanceUpgrade(toAddress)
    propId = tx.events["UpgradeProposed"]["proposalId"]

    chain.sleep(TIMELOCK_DURATION + 1)
    chain.mine()

    tx = emergency_recovery.completeGovernanceUpgrade(propId)
    assert "UpgradeExecuted" in tx.events
    assert mock_proxy._upgradeTo() == toAddress


def test_cannot_complete_if_vetoed(emergency_recovery, mock_proxy):
    toAddress = accounts[1]
    tx = emergency_recovery.startGovernanceUpgrade(toAddress)
    propId = tx.events["UpgradeProposed"]["proposalId"]

    tx = emergency_recovery.veto(propId)
    assert tx.events["VetoCast"]["castVetoPower"] == [
        ("0x0000000000000000000000000000000000000001", 21e18)
    ]

    chain.sleep(TIMELOCK_DURATION + 1)
    chain.mine()

    tx = emergency_recovery.completeGovernanceUpgrade(propId)
    assert tx.events["UpgradeVetoed"]["proposalId"] == propId

    with reverts("proposal must be queued"):
        emergency_recovery.completeGovernanceUpgrade(propId)


def test_can_complete_after_sunset(emergency_recovery, mock_proxy):
    toAddress = accounts[1]
    tx = emergency_recovery.startGovernanceUpgrade(toAddress)
    propId = tx.events["UpgradeProposed"]["proposalId"]

    chain.sleep(SUNSET_DURATION + 1)
    chain.mine()

    tx = emergency_recovery.completeGovernanceUpgrade(propId)
    assert "UpgradeExecuted" in tx.events


def test_doesnt_double_count_vetos(
    emergency_recovery, mock_voting_aggregator, mock_proxy
):
    toAddress = accounts[1]
    tx = emergency_recovery.startGovernanceUpgrade(toAddress)
    propId = tx.events["UpgradeProposed"]["proposalId"]

    tx = emergency_recovery.veto(propId)
    assert tx.events["VetoCast"]["castVetoPower"] == [
        ("0x0000000000000000000000000000000000000001", 21e18)
    ]
    assert emergency_recovery.getVetoPercentage(propId) == 0.21e18

    mock_voting_aggregator.setVotingPower(30e18)
    tx = emergency_recovery.veto(propId)
    assert tx.events["VetoCast"]["castVetoPower"] == [
        ("0x0000000000000000000000000000000000000001", 30e18)
    ]
    assert emergency_recovery.getVetoPercentage(propId) == 0.30e18


def test_cannot_veto_if_out_of_timelock(emergency_recovery, mock_proxy):
    toAddress = accounts[1]
    tx = emergency_recovery.startGovernanceUpgrade(toAddress)
    propId = tx.events["UpgradeProposed"]["proposalId"]

    chain.sleep(TIMELOCK_DURATION + 1)
    chain.mine()

    with reverts("proposal is out of timelock"):
        emergency_recovery.veto(propId)


def test_cannot_veto_if_doesnt_exist(emergency_recovery, mock_proxy):
    with reverts("proposal does not exist"):
        emergency_recovery.veto(1)


def test_reverts_if_proposal_does_not_exist(emergency_recovery, mock_proxy):
    with reverts("proposal does not exist"):
        emergency_recovery.completeGovernanceUpgrade(1)


def test_reverts_if_proposal_is_timelocked(emergency_recovery, mock_proxy):
    toAddress = accounts[1]
    tx = emergency_recovery.startGovernanceUpgrade(toAddress)
    propId = tx.events["UpgradeProposed"]["proposalId"]

    with reverts("proposal is still timelocked"):
        emergency_recovery.completeGovernanceUpgrade(propId)


def test_reverts_if_upgrade_not_started_from_safe(admin, emergency_recovery):
    toAddress = accounts[1]
    with reverts(""):
        emergency_recovery.startGovernanceUpgrade(toAddress, {"from": accounts[-1]})


@pytest.mark.parametrize(
    "getter,setter,_input",
    [
        ("sunsetAt", "setSunsetAt", 20 * 60 * 60),
        ("vetoThreshold", "setVetoThreshold", 5e17),
        ("timelockDuration", "setTimelockDuration", 2 * 60 * 60),
    ],
)
def test_setters(
    admin, emergency_recovery_with_admin_governance, getter, setter, _input
):
    getattr(emergency_recovery_with_admin_governance, setter)(_input, {"from": admin})
    assert getattr(emergency_recovery_with_admin_governance, getter)() == _input
