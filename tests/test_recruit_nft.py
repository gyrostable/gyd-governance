from brownie import reverts


def test_recruit_nft_is_not_transferable(admin, accounts, recruit_nft, nft_vault):
    with reverts("cannot transfer NFT"):
        recruit_nft.transferFrom(admin, accounts[1], 0)


def test_recruit_nft_is_mintable_by_allowlisted_address(
    admin, accounts, recruit_nft, nft_vault
):
    acc = accounts[1]
    with reverts("must be allowlisted or owner to call this function"):
        recruit_nft.mint(acc, 200, {"from": acc})

    recruit_nft.addToAllowlist(acc, {"from": admin})
    recruit_nft.mint(acc, 200, {"from": acc})
