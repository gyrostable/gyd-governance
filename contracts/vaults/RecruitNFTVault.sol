// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./NFTVault.sol";
import "../../libraries/VotingPowerHistory.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/IVotingPowersUpdater.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract RecruitNFTVault is NFTVault, IVotingPowersUpdater {
    using VotingPowerHistory for VotingPowerHistory.History;
    using VotingPowerHistory for VotingPowerHistory.Record;

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
        VotingPowerHistory.Record memory ovp = history.currentRecord(_user);

        uint256 oldTotal = ovp.total();
        VotingPowerHistory.Record memory nvp = history.updateVotingPower(
            _user,
            ovp.baseVotingPower + _addedCount,
            ovp.multiplier,
            ovp.netDelegatedVotes
        );
        sumVotingPowers += (nvp.total() - oldTotal);
    }
}
