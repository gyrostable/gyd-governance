// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../contracts/NFTVault.sol";
import "../interfaces/IVotingPowersUpdater.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract RecruitNFTVault is NFTVault, IVotingPowersUpdater {
    address internal immutable underlyingAddress;

    constructor(
        address _owner,
        address _underlyingAddress,
        uint256 _underlyingSupply
    ) NFTVault(_owner) {
        underlyingAddress = _underlyingAddress;
        sumVotingPowers = _underlyingSupply;
    }

    modifier onlyUnderlying() {
        require(msg.sender == address(underlyingAddress));
        _;
    }

    function updateVotingPower(
        address _user,
        uint256 _addedVotingPower
    ) external onlyUnderlying {
        ownVotingPowers[_user] += _addedVotingPower;
        sumVotingPowers += _addedVotingPower;
    }
}
