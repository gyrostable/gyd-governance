// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./NFTVault.sol";
import "../../libraries/BaseVotingPower.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/IVotingPowersUpdater.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract RecruitNFTVault is NFTVault, IVotingPowersUpdater {
    using BaseVotingPower for DataTypes.BaseVotingPower;

    address internal immutable underlyingAddress;

    constructor(address _owner, address _underlyingAddress) NFTVault(_owner) {
        underlyingAddress = _underlyingAddress;
        sumVotingPowers = IERC721Enumerable(_underlyingAddress).totalSupply();
    }

    modifier onlyUnderlying() {
        require(msg.sender == address(underlyingAddress));
        _;
    }

    function updateBaseVotingPower(
        address _user,
        uint128 _addedCount
    ) external onlyUnderlying {
        DataTypes.BaseVotingPower storage ovp = ownVotingPowers[_user];
        uint256 oldTotal = ovp.total();
        ovp.initialize();
        ovp.base += _addedCount;
        sumVotingPowers += (ovp.total() - oldTotal);
    }
}
