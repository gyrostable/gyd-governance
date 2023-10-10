from brownie import chain
from brownie.test.managers.runner import RevertContextManager as reverts

from tests.conftest import (
    ABSTAIN_BALLOT,
    AGAINST_BALLOT,
    FOR_BALLOT,
    PROPOSAL_LENGTH_DURATION,
    QUORUM_NOT_MET_OUTCOME,
    SUCCESSFUL_OUTCOME,
    THRESHOLD_NOT_MET_OUTCOME,
    TIMELOCKED_DURATION,
    UNDEFINED_BALLOT,
    Proposal,
    ProposalAction,
    ProposalStatus,
    Tier,
    VoteTotals,
)
from tests.support.utils import typed_reverts


def test_create_proposal(governance_manager, admin):
    proposal = ProposalAction.function_call(admin.address, "totalSupply()")
    tx = governance_manager.createProposal([proposal])

    aps = governance_manager.listActiveProposals()
    assert len(aps) == 1

    assert aps[0][8] == 1  # check status, active = 1

    createdProposal = aps[0]
    assert tx.events["ProposalCreated"]["id"] == createdProposal[5]
    assert proposal == createdProposal[-1][0]


def test_create_proposal_without_sufficient_voting_power(
    governance_manager, admin, mock_vault, chain
):
    mock_vault.updateVotingPower(admin, 1e18)
    chain.sleep(1)
    proposal = ProposalAction.function_call(admin.address, "totalSupply()")
    with reverts("proposer doesn't have enough voting power to propose this action"):
        governance_manager.createProposal([proposal])


def test_vote_on_proposal_which_doesnt_exist(governance_manager, admin):
    with reverts("proposal does not exist"):
        governance_manager.vote(1, FOR_BALLOT)


def test_vote_on_inactive_proposal(governance_manager, admin):
    proposal = ProposalAction.function_call(admin.address, "totalSupply()")
    tx = governance_manager.createProposal([proposal])

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    with reverts("voting is closed on this proposal"):
        governance_manager.vote(tx.events["ProposalCreated"]["id"], AGAINST_BALLOT)


def test_instant_vote(governance_manager, admin):
    proposal = ProposalAction.function_call(admin.address, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    with reverts("voting has not started"):
        governance_manager.vote(tx.events["ProposalCreated"]["id"], AGAINST_BALLOT)


def test_invalid_vote(governance_manager, admin, chain):
    proposal = ProposalAction.function_call(admin.address, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    chain.sleep(1)
    with reverts("ballot must be cast For, Against, or Abstain"):
        governance_manager.vote(tx.events["ProposalCreated"]["id"], UNDEFINED_BALLOT)


def test_vote(mock_vault, governance_manager, admin):
    mv = mock_vault
    proposal = ProposalAction.function_call(admin.address, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    chain.sleep(1)
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, AGAINST_BALLOT)
    vote_totals = governance_manager.getVoteTotals(propId)
    assert vote_totals == VoteTotals(
        for_=[], against=[(mv.address, 50e18)], abstentions=[]
    )


def test_vote_doesnt_double_count_if_vote_is_changed(
    mock_vault, governance_manager, admin
):
    mv = mock_vault
    proposal = ProposalAction.function_call(admin.address, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    chain.sleep(1)
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, AGAINST_BALLOT)

    assert tx.events["VoteCast"]["vote"] == AGAINST_BALLOT

    tx = governance_manager.vote(propId, FOR_BALLOT)
    vote_totals = governance_manager.getVoteTotals(propId)
    assert vote_totals == VoteTotals(
        for_=[(mv.address, 50e18)], against=[(mv.address, 0)], abstentions=[]
    )


def test_tally(governance_manager, raising_token):
    proposal = ProposalAction.function_call(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    chain.sleep(1)
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


def test_tally_vote_doesnt_succeed(governance_manager, raising_token):
    proposal = ProposalAction.function_call(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    chain.sleep(1)
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, AGAINST_BALLOT)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == THRESHOLD_NOT_MET_OUTCOME


def test_tally_vote_doesnt_meet_quorum(
    admin, governance_manager, raising_token, mock_vault, chain
):
    mock_vault.updateVotingPower(admin, 6e18)
    chain.sleep(1)
    chain.mine()
    print(mock_vault.getRawVotingPower(admin) / mock_vault.getTotalRawVotingPower())
    proposal = ProposalAction.function_call(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    chain.sleep(1)
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, FOR_BALLOT)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == QUORUM_NOT_MET_OUTCOME


def test_tally_vote_abstentions_contribute_to_quorum(governance_manager, raising_token):
    proposal = ProposalAction.function_call(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    chain.sleep(1)
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, ABSTAIN_BALLOT)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == THRESHOLD_NOT_MET_OUTCOME


def test_tally_result_determined_by_for_and_against_not_abstentions(
    governance_manager,
    raising_token,
    admin,
    accounts,
):
    proposal = ProposalAction.function_call(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    chain.sleep(1)
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


def test_tally_inactive_proposal(governance_manager, raising_token):
    proposal = ProposalAction.function_call(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    chain.sleep(1)
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, FOR_BALLOT)

    proposal_duration = PROPOSAL_LENGTH_DURATION + 1
    chain.sleep(proposal_duration)
    chain.mine()

    tx = governance_manager.tallyVote(propId)
    assert tx.events["ProposalTallied"]["outcome"] == SUCCESSFUL_OUTCOME

    with reverts("proposal is not currently active"):
        governance_manager.tallyVote(propId)


def test_tally_ongoing_proposal(governance_manager, raising_token):
    proposal = ProposalAction.function_call(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    chain.sleep(1)
    propId = tx.events["ProposalCreated"]["id"]
    tx = governance_manager.vote(propId, FOR_BALLOT)

    with reverts("voting is ongoing for this proposal"):
        governance_manager.tallyVote(propId)


def test_tally_proposal_doesnt_exist(governance_manager):
    with reverts("proposal does not exist"):
        governance_manager.tallyVote(1)


def test_execute_must_be_queued(governance_manager, raising_token):
    proposal = ProposalAction.function_call(raising_token, "totalSupply()")
    tx = governance_manager.createProposal([proposal])
    propId = tx.events["ProposalCreated"]["id"]

    with reverts("proposal must be queued and ready to execute"):
        tx = governance_manager.executeProposal(propId)


def test_uses_override_tier_if_enough_gyd_is_bounded(
    admin, governance_manager, bounded_erc20, token
):
    proposal = ProposalAction.function_call(governance_manager, "upgradeTo()")
    tx = governance_manager.createProposal([proposal])

    prop = governance_manager.listActiveProposals()[-1]
    assert prop[3] == 1e17  # vote threshold

    token.approve(bounded_erc20.address, 100, {"from": admin})
    bounded_erc20.deposit(100, {"from": admin})
    chain.mine()

    # trigger another update since the EMA lags by one update.
    bounded_erc20.updateEMA({"from": admin})
    chain.mine()
    bounded_erc20.updateEMA({"from": admin})

    tx = governance_manager.createProposal([proposal])

    prop = governance_manager.listActiveProposals()[-1]
    assert prop[3] == 4e17  # vote threshold


def test_uses_highest_tier_if_multiple_proposals_made(
    admin, governance_manager, mock_tierer
):
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
        ProposalAction.function_call(governance_manager, "upgradeTo()"),
        ProposalAction.function_call(admin, "upgradeTo()"),
    ]
    tx = governance_manager.createProposal(proposals)

    prop = governance_manager.listActiveProposals()[-1]
    assert prop[3] == 5e17  # vote threshold


def test_voting_power_snapshot(
    governance_manager,
    accounts,
    mock_vault,
    admin,
    alice,
    chain,
    charlie,
    voting_power_aggregator,
):
    # reset voting power
    mock_vault.updateVotingPower(admin, 0)
    mock_vault.updateVotingPower(alice, 0)
    mock_vault.updateVotingPower(charlie, 80e18)
    chain.sleep(1)

    # give 20e18 of voting power to account[2] and delegate all of it to acccount[1]
    mock_vault.updateVotingPower(accounts[2], 20e18)
    mock_vault.delegateVote(accounts[1], 20e18, {"from": accounts[2]})

    # create proposal and vote
    proposal = ProposalAction.function_call(admin.address, "totalSupply()")
    chain.sleep(1)
    chain.mine()
    tx = governance_manager.createProposal([proposal], {"from": accounts[1]})
    proposal_id = tx.events["ProposalCreated"]["id"]
    chain.sleep(1)  # make sure timestamp has changed
    mock_vault.updateVotingPower(accounts[1], 30e18)
    governance_manager.vote(proposal_id, AGAINST_BALLOT, {"from": accounts[1]})

    # ensure that the total voting power is snapshotted correctly with # 20% of votes against
    assert governance_manager.getCurrentPercentages(proposal_id)[1] == 0.2e18
    mock_vault.updateVotingPower(charlie, 130e18)
    chain.sleep(1)
    assert governance_manager.getCurrentPercentages(proposal_id)[1] == 0.2e18

    # ensure vote is recorded correctly
    totals = governance_manager.getVoteTotals(proposal_id)
    assert totals["against"][0][1] == 20e18

    # ensure that delegating and voting from another address doesn't change the vote
    mock_vault.changeDelegate(accounts[1], accounts[8], 20e18, {"from": accounts[2]})
    governance_manager.vote(proposal_id, FOR_BALLOT, {"from": accounts[8]})
    assert governance_manager.getVoteTotals(proposal_id)["against"][0][1] == 20e18
    assert governance_manager.getVoteTotals(proposal_id)["_for"][0][1] == 0

    # ensure that undelegating and voting from user's address doesn't change the vote
    mock_vault.undelegateVote(accounts[8], 20e18, {"from": accounts[2]})
    governance_manager.vote(proposal_id, AGAINST_BALLOT, {"from": accounts[2]})
    assert governance_manager.getVoteTotals(proposal_id)["against"][0][1] == 20e18
    assert governance_manager.getVoteTotals(proposal_id)["_for"][0][1] == 0

    # ensure that user with voting power at vote time can change his vote
    governance_manager.vote(proposal_id, FOR_BALLOT, {"from": accounts[1]})
    assert governance_manager.getVoteTotals(proposal_id)["against"][0][1] == 0
    assert governance_manager.getVoteTotals(proposal_id)["_for"][0][1] == 20e18


def test_create_and_execute_proposal(governance_manager, admin, MockProxy, multisig):
    test_contract = admin.deploy(MockProxy)
    action = ProposalAction.function_call(
        test_contract.address, "upgradeTo(address)", governance_manager.address
    )

    with typed_reverts("NotAuthorized(address,address)"):
        governance_manager.createAndExecuteProposal([action], {"from": admin})

    tx = governance_manager.createAndExecuteProposal([action], {"from": multisig})
    proposal_id = tx.events["ProposalCreated"]["id"]
    assert proposal_id == 0
    assert tx.events["ProposalExecuted"]["proposalId"] == 0

    proposal = Proposal(*governance_manager.getProposal(proposal_id))
    assert proposal.status == ProposalStatus.Executed

    assert test_contract._upgradeTo() == governance_manager.address

    chain.sleep(90 * 86400)
    with typed_reverts("MultisigSunset()"):
        governance_manager.createAndExecuteProposal([action], {"from": multisig})


def test_veto_proposal(governance_manager, admin, multisig):
    action = ProposalAction.function_call(admin.address, "totalSupply()")
    tx = governance_manager.createProposal([action])
    proposal_id = tx.events["ProposalCreated"]["id"]
    proposal = Proposal(*governance_manager.getProposal(proposal_id))
    assert proposal.status == ProposalStatus.Active

    with typed_reverts("NotAuthorized(address,address)"):
        governance_manager.vetoProposal(proposal_id, {"from": admin})

    tx = governance_manager.vetoProposal(proposal_id, {"from": multisig})
    assert tx.events["ProposalVetoed"]["proposalId"] == proposal_id
    proposal = Proposal(*governance_manager.getProposal(proposal_id))
    assert proposal.status == ProposalStatus.Vetoed


def test_multisig_sunset(governance_manager, admin, multisig):
    action = ProposalAction.function_call(
        governance_manager.address, "sunsetMultisig()"
    )
    tx = governance_manager.createProposal([action])
    proposal_id = tx.events["ProposalCreated"]["id"]
    proposal = Proposal(*governance_manager.getProposal(proposal_id))
    chain.sleep(1)
    governance_manager.vote(proposal_id, FOR_BALLOT)
    chain.sleep(proposal.votingEndsAt - chain.time() + 1)
    governance_manager.tallyVote(proposal_id)
    proposal = Proposal(*governance_manager.getProposal(proposal_id))
    assert proposal.status == ProposalStatus.Queued
    chain.sleep(proposal.executableAt - chain.time() + 1)
    tx = governance_manager.executeProposal(proposal_id)
    assert governance_manager.multisigSunsetAt() == tx.timestamp

    action = ProposalAction.function_call(admin.address, "totalSupply()")
    with typed_reverts("MultisigSunset()"):
        governance_manager.createAndExecuteProposal([action], {"from": multisig})
