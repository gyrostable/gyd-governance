from typing import NamedTuple, Union
from eth_utils.abi import function_signature_to_4byte_selector
from brownie import chain
from brownie.test.managers.runner import RevertContextManager as reverts
from tests.conftest import (
    FOR_BALLOT,
    AGAINST_BALLOT,
    UNDEFINED_BALLOT,
    ABSTAIN_BALLOT,
    PROPOSAL_LENGTH_DURATION,
    TIMELOCKED_DURATION,
    QUORUM_NOT_MET_OUTCOME,
    THRESHOLD_NOT_MET_OUTCOME,
    SUCCESSFUL_OUTCOME,
    Tier,
)


class ProposalAction(NamedTuple):
    target: int
    data: Union[str, bytes]

    @classmethod
    def nullary_function(cls, target, function_name, *args):
        return cls(
            target, "0x" + function_signature_to_4byte_selector(function_name).hex()
        )


class VoteTotals(NamedTuple):
    for_: list
    against: list
    abstentions: list


def test_create_proposal(MockVault, governance_manager, voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5e18, 10e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(admin.address, "totalSupply()")
    tx = governance_manager.createProposal([proposal])

    aps = governance_manager.listActiveProposals()
    assert len(aps) == 1

    createdProposal = aps[0]
    assert tx.events["ProposalCreated"]["id"] == createdProposal[5]
    assert proposal == createdProposal[-1][0]


def test_create_proposal_without_sufficient_voting_power(
    MockVault, governance_manager, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 0, 10e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(admin.address, "totalSupply()")
    with reverts("proposer doesn't have enough voting power to propose this action"):
        governance_manager.createProposal([proposal])


def test_vote_on_proposal_which_doesnt_exist(
    governance_manager, voting_power_aggregator, admin
):
    with reverts("proposal does not exist"):
        governance_manager.vote(1, FOR_BALLOT)


def test_vote_on_inactive_proposal(
    MockVault, governance_manager, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 5e18, 10e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(admin.address, "totalSupply()")
    tx = governance_manager.createProposal([proposal])

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    with reverts("voting is closed on this proposal"):
        governance_manager.vote(tx.events["ProposalCreated"]["id"], AGAINST_BALLOT)


def test_invalid_vote(MockVault, governance_manager, voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5e18, 10e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(admin.address, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    with reverts("ballot must be cast FOR, AGAINST, or ABSTAIN"):
        governance_manager.vote(tx.events["ProposalCreated"]["id"], UNDEFINED_BALLOT)


def test_vote(MockVault, governance_manager, voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5e18, 10e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(admin.address, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    tx = governance_manager.vote(tx.events["ProposalCreated"]["id"], AGAINST_BALLOT)
    assert tx.events["VoteCast"]["votingPower"][0] == (mv.address, 5e18)


def test_vote_doesnt_double_count_if_vote_is_changed(
    MockVault, governance_manager, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 5e18, 10e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(admin.address, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, AGAINST_BALLOT)

    assert tx.events["VoteCast"]["vote"] == AGAINST_BALLOT

    tx = governance_manager.vote(propId, FOR_BALLOT)
    assert tx.events["VoteCast"]["voteTotals"] == VoteTotals(
        for_=[(mv.address, 5e18)], against=[(mv.address, 0)], abstentions=[]
    )


def test_tally(
    MockVault, governance_manager, raising_token, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, FOR_BALLOT)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == SUCCESSFUL_OUTCOME

    aps = governance_manager.listActiveProposals()
    assert len(aps) == 0

    tps = governance_manager.listTimelockedProposals()
    assert len(tps) == 1

    chain.sleep(TIMELOCKED_DURATION + 1)
    chain.mine()

    with reverts("function raised exception"):
        # success == True just means the the call didn't raise
        # an exception, not that it actually did anything,
        # so to test this the `raising_token` raises on calls to
        # totalSupply()
        tx = governance_manager.executeProposal(propId)


def test_tally_vote_doesnt_succeed(
    MockVault, governance_manager, raising_token, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, AGAINST_BALLOT)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == THRESHOLD_NOT_MET_OUTCOME


def test_tally_vote_doesnt_meet_quorum(
    MockVault, governance_manager, raising_token, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 11e18, 100e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, FOR_BALLOT)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == QUORUM_NOT_MET_OUTCOME


def test_tally_vote_abstentions_contribute_to_quorum(
    MockVault, governance_manager, raising_token, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, ABSTAIN_BALLOT)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == THRESHOLD_NOT_MET_OUTCOME


def test_tally_result_determined_by_for_and_against_not_abstentions(
    MockVault,
    governance_manager,
    raising_token,
    voting_power_aggregator,
    admin,
    accounts,
):
    mv = admin.deploy(MockVault, 20e18, 100e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    propId = tx.events["ProposalCreated"]["id"]

    # voteThreshold is 1e17, so since each vote has 20 voting power (out of 100 for the
    # vault), with a weight of 1, this means the total for vaults will be 50%, passing the
    # threshold.
    tx = governance_manager.vote(propId, FOR_BALLOT)
    tx = governance_manager.vote(propId, AGAINST_BALLOT, {"from": accounts[1]})

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == SUCCESSFUL_OUTCOME


def test_tally_inactive_proposal(
    MockVault, governance_manager, raising_token, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, FOR_BALLOT)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == SUCCESSFUL_OUTCOME

    with reverts("proposal is not currently active"):
        governance_manager.tallyVote(propId)


def test_tally_ongoing_proposal(
    MockVault, governance_manager, raising_token, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, FOR_BALLOT)

    with reverts("voting is ongoing for this proposal"):
        governance_manager.tallyVote(propId)


def test_tally_proposal_doesnt_exist(
    governance_manager, raising_token, voting_power_aggregator, admin
):
    with reverts("proposal does not exist"):
        governance_manager.tallyVote(1)


def test_execute_must_be_queued(
    MockVault, governance_manager, raising_token, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    propId = tx.events["ProposalCreated"]["id"]

    with reverts("proposal must be queued and ready to execute"):
        tx = governance_manager.executeProposal(propId)


def test_uses_override_tier_if_enough_gyd_is_wrapped(
    MockVault, admin, voting_power_aggregator, governance_manager, wrapped_erc20, token
):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    proposal = ProposalAction.nullary_function(governance_manager, "upgradeTo()")
    tx = governance_manager.createProposal([proposal])

    prop = governance_manager.listActiveProposals()[-1]
    assert prop[3] == 1e17  # vote threshold

    token.approve(wrapped_erc20.address, 100, {"from": admin})
    wrapped_erc20.deposit(100, {"from": admin})
    chain.mine()

    # trigger another update since the EMA lags by one update.
    wrapped_erc20.updateEMA({"from": admin})
    chain.mine()

    tx = governance_manager.createProposal([proposal])

    prop = governance_manager.listActiveProposals()[-1]
    assert prop[3] == 4e17  # vote threshold


def test_uses_highest_tier_if_multiple_proposals_made(
    MockVault, admin, voting_power_aggregator, governance_manager, mock_tierer
):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule([(mv, 1e18, 1e18)], ct, ct + 1, {"from": admin})

    strict_tier = Tier(
        quorum=int(1e17),  # 0.1
        proposal_threshold=int(1e17),  # 0.1
        vote_threshold=int(5e17),  # 0.5
        time_lock_duration=10,  # 10s
        proposal_length=10,  # 10s
        action_level=100,
    )
    mock_tierer.setOverride(governance_manager, strict_tier)

    proposals = [
        ProposalAction.nullary_function(governance_manager, "upgradeTo()"),
        ProposalAction.nullary_function(admin, "upgradeTo()"),
    ]
    tx = governance_manager.createProposal(proposals)

    prop = governance_manager.listActiveProposals()[-1]
    assert prop[3] == 5e17  # vote threshold
