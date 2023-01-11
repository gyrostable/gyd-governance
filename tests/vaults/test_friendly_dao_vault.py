from brownie import reverts
from tests.support.utils import scale


def test_update_dao_and_total_weight(friendly_dao_vault, dummy_dao_addresses):
    dao_address = dummy_dao_addresses[0]
    friendly_dao_vault.updateDAOAndTotalWeight(dao_address, scale("0.5"), scale("1"))

    assert friendly_dao_vault.getRawVotingPower(dao_address) == scale("0.5")
    assert friendly_dao_vault.getTotalRawVotingPower() == scale("1")


def test_update_doa_and_total_weight_reverts_if_actual_total_too_much(
    friendly_dao_vault, dummy_dao_addresses
):
    friendly_dao_vault.updateDAOAndTotalWeight(
        dummy_dao_addresses[0], scale("0.5"), scale("1")
    )
    with reverts():
        friendly_dao_vault.updateDAOAndTotalWeight(
            dummy_dao_addresses[1], scale("0.6"), scale("1")
        )
