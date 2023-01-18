from typing import NamedTuple
from eth_utils import function_signature_to_4byte_selector
from brownie import MockVault, reverts, chain
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
)


class ProposalAction(NamedTuple):
    target: int
    data: bytes


class VoteTotals(NamedTuple):
    for_: int
    against: int
    abstain: int


def test_create_proposal(governance_manager, voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5e18, 10e18)
    voting_power_aggregator.updateVaults([(mv, 1e18)], {"from": admin})

    proposal = ProposalAction(
        admin.address,
        "0x" + function_signature_to_4byte_selector("totalSupply()").hex(),
    )
    tx = governance_manager.createProposal(proposal)

    aps = governance_manager.listActiveProposals()
    assert len(aps) == 1

    createdProposal = aps[0]
    assert tx.events["ProposalCreated"]["id"] == createdProposal[5]
    assert proposal == createdProposal[-1]


def test_create_proposal_without_sufficient_voting_power(
    governance_manager, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 0, 10e18)
    voting_power_aggregator.updateVaults([(mv, 1e18)], {"from": admin})

    proposal = ProposalAction(
        admin.address,
        "0x" + function_signature_to_4byte_selector("totalSupply()").hex(),
    )
    with reverts("proposer doesn't have enough voting power to propose this action"):
        governance_manager.createProposal(proposal)


def test_vote_on_proposal_which_doesnt_exist(
    governance_manager, voting_power_aggregator, admin
):
    with reverts("proposal does not exist"):
        governance_manager.vote(1, FOR_BALLOT)


def test_vote_on_inactive_proposal(governance_manager, voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5e18, 10e18)
    voting_power_aggregator.updateVaults([(mv, 1e18)], {"from": admin})

    proposal = ProposalAction(
        admin.address,
        "0x" + function_signature_to_4byte_selector("totalSupply()").hex(),
    )
    tx = governance_manager.createProposal(proposal)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    with reverts("voting is closed on this proposal"):
        governance_manager.vote(tx.events["ProposalCreated"]["id"], AGAINST_BALLOT)


def test_invalid_vote(governance_manager, voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5e18, 10e18)
    voting_power_aggregator.updateVaults([(mv, 1e18)], {"from": admin})

    proposal = ProposalAction(
        admin.address,
        "0x" + function_signature_to_4byte_selector("totalSupply()").hex(),
    )
    tx = governance_manager.createProposal(proposal)
    with reverts("ballot must be cast FOR, AGAINST, or ABSTAIN"):
        governance_manager.vote(tx.events["ProposalCreated"]["id"], UNDEFINED_BALLOT)


def test_vote(governance_manager, voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5e18, 10e18)
    voting_power_aggregator.updateVaults([(mv, 1e18)], {"from": admin})

    proposal = ProposalAction(
        admin.address,
        "0x" + function_signature_to_4byte_selector("totalSupply()").hex(),
    )
    tx = governance_manager.createProposal(proposal)
    tx = governance_manager.vote(tx.events["ProposalCreated"]["id"], AGAINST_BALLOT)
    assert tx.events["VoteCast"]["voteTotals"] == (0, 5e18, 0)


def test_vote_doesnt_double_count_if_vote_is_changed(
    governance_manager, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 5e18, 10e18)
    voting_power_aggregator.updateVaults([(mv, 1e18)], {"from": admin})

    proposal = ProposalAction(
        admin.address,
        "0x" + function_signature_to_4byte_selector("totalSupply()").hex(),
    )
    tx = governance_manager.createProposal(proposal)
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, AGAINST_BALLOT)

    assert tx.events["VoteCast"]["voteTotals"] == VoteTotals(
        for_=0, against=5e18, abstain=0
    )

    tx = governance_manager.vote(propId, FOR_BALLOT)
    assert tx.events["VoteCast"]["voteTotals"] == VoteTotals(
        for_=5e18, against=0, abstain=0
    )


def test_tally(governance_manager, raising_token, voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    voting_power_aggregator.updateVaults([(mv, 1e18)], {"from": admin})

    proposal = ProposalAction(
        raising_token,
        "0x" + function_signature_to_4byte_selector("totalSupply()").hex(),
    )
    tx = governance_manager.createProposal(proposal)
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
    governance_manager, raising_token, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    voting_power_aggregator.updateVaults([(mv, 1e18)], {"from": admin})

    proposal = ProposalAction(
        raising_token,
        "0x" + function_signature_to_4byte_selector("totalSupply()").hex(),
    )
    tx = governance_manager.createProposal(proposal)
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, AGAINST_BALLOT)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == THRESHOLD_NOT_MET_OUTCOME


def test_tally_vote_doesnt_meet_quorum(
    governance_manager, raising_token, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 11e18, 100e18)
    voting_power_aggregator.updateVaults([(mv, 1e18)], {"from": admin})

    proposal = ProposalAction(
        raising_token,
        "0x" + function_signature_to_4byte_selector("totalSupply()").hex(),
    )
    tx = governance_manager.createProposal(proposal)
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, FOR_BALLOT)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == QUORUM_NOT_MET_OUTCOME


def test_tally_vote_abstentions_contribute_to_quorum(
    governance_manager, raising_token, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    voting_power_aggregator.updateVaults([(mv, 1e18)], {"from": admin})

    proposal = ProposalAction(
        raising_token,
        "0x" + function_signature_to_4byte_selector("totalSupply()").hex(),
    )
    tx = governance_manager.createProposal(proposal)
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, ABSTAIN_BALLOT)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == THRESHOLD_NOT_MET_OUTCOME


def test_tally_inactive_proposal(
    governance_manager, raising_token, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    voting_power_aggregator.updateVaults([(mv, 1e18)], {"from": admin})

    proposal = ProposalAction(
        raising_token,
        "0x" + function_signature_to_4byte_selector("totalSupply()").hex(),
    )
    tx = governance_manager.createProposal(proposal)
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, FOR_BALLOT)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == SUCCESSFUL_OUTCOME

    with reverts("proposal is not currently active"):
        governance_manager.tallyVote(propId)


def test_tally_inactive_proposal(
    governance_manager, raising_token, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    voting_power_aggregator.updateVaults([(mv, 1e18)], {"from": admin})

    proposal = ProposalAction(
        raising_token,
        "0x" + function_signature_to_4byte_selector("totalSupply()").hex(),
    )
    tx = governance_manager.createProposal(proposal)
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
    governance_manager, raising_token, voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 50e18, 100e18)
    voting_power_aggregator.updateVaults([(mv, 1e18)], {"from": admin})

    proposal = ProposalAction(
        raising_token,
        "0x" + function_signature_to_4byte_selector("totalSupply()").hex(),
    )
    tx = governance_manager.createProposal(proposal)
    propId = tx.events["ProposalCreated"]["id"]

    with reverts("proposal must be queued and ready to execute"):
        tx = governance_manager.executeProposal(propId)