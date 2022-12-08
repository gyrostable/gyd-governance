// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../../interfaces/IVotingPowersUpdater.sol";
import "./access/ImmutableOwner.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract RecruitNFT is ERC721Enumerable, ImmutableOwner {
    constructor(
        string memory _name,
        string memory _ticker,
        address _owner
    ) ERC721(_name, _ticker) ImmutableOwner(_owner) {}

    IVotingPowersUpdater private vault;

    function setGovernanceVault(address _vault) public onlyOwner {
        vault = IVotingPowersUpdater(_vault);
    }

    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
        vault.updateVotingPower(to, 1);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override {
        // `from == address(0)` in the case of mints.
        // In all other cases we want to revert to make
        // the NFT non-transferable.
        require(from == address(0), "cannot transfer NFT");
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }
}
