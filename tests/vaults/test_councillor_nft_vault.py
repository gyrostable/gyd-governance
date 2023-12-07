def test_sum_voting_powers(admin, accounts, nft_vault, councillor_nft):
    initial_total = 5e18
    assert nft_vault.getTotalRawVotingPower() == initial_total

    admin_voting_power = nft_vault.getRawVotingPower(admin)
    assert admin_voting_power == 1e18
    proposed_admin_multiplier = 5e18
    nft_vault.updateMultiplier([admin], proposed_admin_multiplier, {"from": admin})
    assert nft_vault.getRawVotingPower(admin) == 5e18
    new_total = nft_vault.getTotalRawVotingPower()
    assert new_total == initial_total + (proposed_admin_multiplier - admin_voting_power)

    # minting an NFT updates the total
    acc = accounts.add()
    councillor_nft.mint(acc, 10**18, acc, [], b"", {"from": admin})
    assert nft_vault.getTotalRawVotingPower() == new_total + 1e18
