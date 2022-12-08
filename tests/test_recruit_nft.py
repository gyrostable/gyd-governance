from brownie import reverts


def test_recruit_nft_is_not_transferable(admin, accounts, recruit_nft, nft_vault):
    with reverts("cannot transfer NFT"):
        recruit_nft.transferFrom(admin, accounts[1], 0)
