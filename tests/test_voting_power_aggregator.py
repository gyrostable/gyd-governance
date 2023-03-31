from brownie import reverts, MockVault, chain


def test_set_schedule_with_wrong_start_end(voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5, 10)
    mv2 = admin.deploy(MockVault, 5, 10)

    ct = chain.time() - 1000
    with reverts("schedule must end after it begins"):
        voting_power_aggregator.setSchedule(
            ([(mv, 5e17, 5e17), (mv2, 5e17, 5e17)], ct, ct), {"from": admin}
        )

    with reverts("schedule must end after it begins"):
        voting_power_aggregator.setSchedule(
            ([(mv, 5e17, 5e17), (mv2, 5e17, 5e17)], ct, ct - 1), {"from": admin}
        )


def test_set_schedule(voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5, 10)
    mv2 = admin.deploy(MockVault, 5, 10)

    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule(
        ([(mv, 5e17, 5e17), (mv2, 5e17, 5e17)], ct, ct + 1), {"from": admin}
    )

    vaults = voting_power_aggregator.listVaults()
    expectedVaults = sorted(
        [(mv.address, 5e17, 5e17, 5e17), (mv2.address, 5e17, 5e17, 5e17)],
        key=lambda x: x[0],
    )
    assert sorted(vaults, key=lambda x: x[0]) == expectedVaults


def test_set_schedule_multiple_times(voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5, 10)
    mv2 = admin.deploy(MockVault, 5, 10)
    mv3 = admin.deploy(MockVault, 5, 10)

    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule(
        ([(mv, 5e17, 5e17), (mv2, 5e17, 5e17)], ct, ct + 1), {"from": admin}
    )

    vaults = voting_power_aggregator.listVaults()
    expectedVaults = sorted(
        [(mv.address, 5e17, 5e17, 5e17), (mv2.address, 5e17, 5e17, 5e17)],
        key=lambda x: x[0],
    )
    assert sorted(vaults, key=lambda x: x[0]) == expectedVaults

    voting_power_aggregator.setSchedule(
        ([(mv, 5e17, 5e17), (mv2, 3e17, 3e17), (mv3, 2e17, 2e17)], ct, ct + 1),
        {"from": admin},
    )
    vaults = voting_power_aggregator.listVaults()
    expectedVaults = sorted(
        [
            (mv.address, 5e17, 5e17, 5e17),
            (mv2.address, 3e17, 3e17, 3e17),
            (mv3.address, 2e17, 2e17, 2e17),
        ],
        key=lambda x: x[0],
    )
    assert sorted(vaults, key=lambda x: x[0]) == expectedVaults


def test_set_schedule_raises_if_vaults_dont_add_up_to_1(voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5, 10)
    mv2 = admin.deploy(MockVault, 5, 10)

    with reverts():
        ct = chain.time() - 1000
        voting_power_aggregator.setSchedule(
            ([(mv, 3e17, 3e17), (mv2, 5e17, 5e17)], ct, ct), {"from": admin}
        )


def test_set_schedule_raises_if_duplicate_vaults(voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5, 10)
    mv2 = admin.deploy(MockVault, 5, 10)

    with reverts():
        ct = chain.time() - 1000
        voting_power_aggregator.setSchedule(
            ([(mv, 3e17, 3e17), (mv, 2e17, 2e17), (mv2, 5e17, 5e17)], ct, ct),
            {"from": admin},
        )


def test_get_vault_weight(voting_power_aggregator, admin):
    mv = admin.deploy(MockVault, 5, 10)
    mv2 = admin.deploy(MockVault, 5, 10)
    mv3 = admin.deploy(MockVault, 5, 10)

    ct = chain.time() - 1000
    voting_power_aggregator.setSchedule(
        ([(mv, 2e17, 2e17), (mv2, 5e17, 5e17), (mv3, 3e17, 3e17)], ct, ct + 1),
        {"from": admin},
    )

    assert voting_power_aggregator.getVaultWeight(mv) == 2e17
    assert voting_power_aggregator.getVaultWeight(mv2) == 5e17
    assert voting_power_aggregator.getVaultWeight(mv3) == 3e17


def test_get_vault_weight_on_schedule(time_settable_voting_power_aggregator, admin):
    vpa = time_settable_voting_power_aggregator

    mv = admin.deploy(MockVault, 5, 10)
    mv2 = admin.deploy(MockVault, 5, 10)

    ct1 = chain.time()
    vpa.setCurrentTime(ct1)

    ct2 = ct1 + 1000
    vpa.setSchedule(([(mv, 2e17, 3e17), (mv2, 8e17, 7e17)], ct1, ct2), {"from": admin})

    assert vpa.getVaultWeight(mv) == 2e17
    assert vpa.getVaultWeight(mv2) == 8e17

    vpa.sleep(500)

    assert vpa.getVaultWeight(mv) == 25e16
    assert vpa.getVaultWeight(mv2) == 75e16

    vpa.sleep(2000)

    assert vpa.getVaultWeight(mv) == 3e17
    assert vpa.getVaultWeight(mv2) == 7e17


def test_get_vault_weight_schedule_starts_in_future(
    time_settable_voting_power_aggregator, admin
):
    vpa = time_settable_voting_power_aggregator

    mv = admin.deploy(MockVault, 5, 10)
    mv2 = admin.deploy(MockVault, 5, 10)

    ct = chain.time()
    vpa.setCurrentTime(ct)

    ct1 = chain.time() + 1000
    ct2 = ct1 + 1000
    vpa.setSchedule(([(mv, 2e17, 3e17), (mv2, 8e17, 7e17)], ct1, ct2), {"from": admin})

    assert vpa.getVaultWeight(mv) == 2e17
    assert vpa.getVaultWeight(mv2) == 8e17

    vpa.sleep(500)

    assert vpa.getVaultWeight(mv) == 2e17
    assert vpa.getVaultWeight(mv2) == 8e17

    vpa.sleep(1000)

    assert vpa.getVaultWeight(mv) == 25e16
    assert vpa.getVaultWeight(mv2) == 75e16
