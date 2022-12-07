from brownie import reverts, MockVault


def test_update_vaults(voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5, 10)
    mv2 = admin.deploy(MockVault, 5, 10)

    voting_power_aggregator.updateVaults([(mv, 5e17), (mv2, 5e17)], {"from": admin})

    vaults = voting_power_aggregator.listVaults()
    expectedVaults = sorted(
        [(mv.address, 5e17), (mv2.address, 5e17)], key=lambda x: x[0]
    )
    assert sorted(vaults, key=lambda x: x[0]) == expectedVaults


def test_update_vaults_raises_if_vaults_dont_add_up_to_1(
    voting_power_aggregator, admin
):
    mv = admin.deploy(MockVault, 5, 10)
    mv2 = admin.deploy(MockVault, 5, 10)

    with reverts():
        voting_power_aggregator.updateVaults([(mv, 3e17), (mv2, 5e17)], {"from": admin})


def test_update_vaults_raises_if_duplicate_vaults(voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5, 10)
    mv2 = admin.deploy(MockVault, 5, 10)

    with reverts():
        voting_power_aggregator.updateVaults(
            [(mv, 3e17), (mv, 2e17), (mv2, 5e17)], {"from": admin}
        )


def test_get_vault_weight(voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5, 10)
    mv2 = admin.deploy(MockVault, 5, 10)
    mv3 = admin.deploy(MockVault, 5, 10)

    voting_power_aggregator.updateVaults(
        [(mv, 2e17), (mv2, 5e17), (mv3, 3e17)], {"from": admin}
    )

    assert voting_power_aggregator.getVaultWeight(mv) == 2e17
    assert voting_power_aggregator.getVaultWeight(mv2) == 5e17
    assert voting_power_aggregator.getVaultWeight(mv3) == 3e17
