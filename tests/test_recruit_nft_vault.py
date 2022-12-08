def test_sum_voting_powers(admin, accounts, nft_vault, recruit_nft):
    initial_total = 5
    assert nft_vault.getTotalRawVotingPower() == initial_total

    admin_voting_power = nft_vault.getRawVotingPower(admin)
    assert admin_voting_power == 1
    proposed_admin_power = 5
    nft_vault.updateRawVotingPower([admin], proposed_admin_power, {"from": admin})
    new_total = nft_vault.getTotalRawVotingPower()
    assert new_total == initial_total + (proposed_admin_power - admin_voting_power)

    # minting an NFT updates the total
    recruit_nft.mint(admin, 5)
    assert nft_vault.getTotalRawVotingPower() == new_total + 1
