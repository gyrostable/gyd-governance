// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../../interfaces/IVotingPowersUpdater.sol";
import "./access/ImmutableOwner.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract RecruitNFT is ERC721Enumerable, ImmutableOwner {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(
        string memory _name,
        string memory _ticker,
        address _owner
    ) ERC721(_name, _ticker) ImmutableOwner(_owner) {}

    IVotingPowersUpdater private vault;

    EnumerableSet.AddressSet private allowlistedAddresses;

    modifier onlyAllowlistedOrOwner() {
        require(
            allowlistedAddresses.contains(msg.sender) || msg.sender == owner,
            "must be allowlisted or owner to call this function"
        );
        _;
    }

    function addToAllowlist(address added) external onlyOwner {
        allowlistedAddresses.add(added);
    }

    function removeFromAllowlist(address removed) external onlyOwner {
        allowlistedAddresses.remove(removed);
    }

    function setGovernanceVault(address _vault) public onlyOwner {
        vault = IVotingPowersUpdater(_vault);
    }

    function mint(address to, uint256 tokenId) public onlyAllowlistedOrOwner {
        _mint(to, tokenId);
        vault.updateBaseVotingPower(to, 1);
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
