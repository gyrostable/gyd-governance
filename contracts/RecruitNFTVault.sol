// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../contracts/NFTVault.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract RecruitNFTVault is NFTVault {
    IERC721Enumerable internal nftContract;

    constructor(address _owner, address tokenAddress) NFTVault(_owner) {
        nftContract = IERC721Enumerable(tokenAddress);
        sumVotingPowers = nftContract.totalSupply();
    }

    // The user's base voting power, without taking into account
    // votes delegated from the user to others, and vice versa.
    // If the user has the NFT, cache this into the contract.
    function _ownVotingPower(address user) internal override returns (uint256) {
        (uint256 balance, bool cached) = _readOwnVotingPower(user);
        if (!cached && balance > 0) {
            ownVotingPowers[user] = balance;
        }
        return balance;
    }

    function _readOwnVotingPower(
        address user
    ) internal view override returns (uint256, bool) {
        uint256 balance = ownVotingPowers[user];
        if (balance > 0) {
            return (balance, true);
        }

        return (nftContract.balanceOf(user), false);
    }
}
