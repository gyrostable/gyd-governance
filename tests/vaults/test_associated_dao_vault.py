from brownie import reverts

from tests.support.utils import scale


def test_update_dao_and_total_weight(associated_dao_vault, dummy_dao_addresses):
    dao_address = dummy_dao_addresses[0]
    associated_dao_vault.updateDAOAndTotalWeight(dao_address, scale("0.5"), scale("1"))

    assert associated_dao_vault.getRawVotingPower(dao_address) == scale("0.5")
    assert associated_dao_vault.getTotalRawVotingPower() == scale("1")


def test_update_doa_and_total_weight_reverts_if_actual_total_too_much(
    associated_dao_vault, dummy_dao_addresses
):
    associated_dao_vault.updateDAOAndTotalWeight(
        dummy_dao_addresses[0], scale("0.5"), scale("1")
    )
    with reverts():
        associated_dao_vault.updateDAOAndTotalWeight(
            dummy_dao_addresses[1], scale("0.6"), scale("1")
        )


def test_delegation(associated_dao_vault, dummy_dao_addresses, accounts):
    associated_dao_vault.updateDAOAndTotalWeight(
        dummy_dao_addresses[0], scale("0.5"), scale("1")
    )
    associated_dao_vault.updateDAOAndTotalWeight(accounts[1], scale("0.5"), scale("1"))
    assert associated_dao_vault.getRawVotingPower(dummy_dao_addresses[0]) == scale(
        "0.5"
    )
    assert associated_dao_vault.getRawVotingPower(accounts[1]) == scale("0.5")

    associated_dao_vault.delegateVote(accounts[2], scale("0.5"), {"from": accounts[1]})
    assert associated_dao_vault.getRawVotingPower(accounts[2]) == scale("0.5")

    associated_dao_vault.changeDelegate(
        accounts[2], accounts[3], scale("0.5"), {"from": accounts[1]}
    )
    assert associated_dao_vault.getRawVotingPower(accounts[2]) == 0
    assert associated_dao_vault.getRawVotingPower(accounts[3]) == scale("0.5")
