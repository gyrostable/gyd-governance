// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../interfaces/IVault.sol";
import "../../interfaces/IDelegatingVault.sol";
import "./../access/ImmutableOwner.sol";
import "../../libraries/DataTypes.sol";
import "../../libraries/VotingPowerHistory.sol";

abstract contract NFTVault is IVault, IDelegatingVault, ImmutableOwner {
    using VotingPowerHistory for VotingPowerHistory.History;
    using VotingPowerHistory for VotingPowerHistory.Record;

    VotingPowerHistory.History internal history;

    uint256 internal sumVotingPowers;

    constructor(address _owner) ImmutableOwner(_owner) {}

    function delegateVote(address _delegate, uint256 _amount) external {
        history.delegateVote(msg.sender, _delegate, _amount);
    }

    function undelegateVote(address _delegate, uint256 _amount) external {
        history.undelegateVote(msg.sender, _delegate, _amount);
    }

    function changeDelegate(
        address _oldDelegate,
        address _newDelegate,
        uint256 _amount
    ) external {
        history.undelegateVote(msg.sender, _oldDelegate, _amount);
        history.delegateVote(msg.sender, _newDelegate, _amount);
    }

    function getRawVotingPower(address user) external view returns (uint256) {
        return history.getVotingPower(user, block.timestamp);
    }

    function getTotalRawVotingPower() external view returns (uint256) {
        return sumVotingPowers;
    }

    function updateMultiplier(
        address[] calldata users,
        uint128 _multiplier
    ) external onlyOwner {
        require(_multiplier >= 1e18, "multiplier cannot be less than 1");
        require(_multiplier <= 20e18, "multiplier cannot be more than 20");
        for (uint i = 0; i < users.length; i++) {
            VotingPowerHistory.Record memory oldVotingPower = history
                .currentRecord(users[i]);
            require(
                oldVotingPower.baseVotingPower >= 1e18,
                "all users must have at least 1 NFT"
            );
            require(
                oldVotingPower.multiplier < _multiplier,
                "cannot decrease voting power"
            );

            uint256 oldTotal = oldVotingPower.total();
            VotingPowerHistory.Record memory newVotingPower = history
                .updateVotingPower(
                    users[i],
                    oldVotingPower.baseVotingPower,
                    _multiplier,
                    oldVotingPower.netDelegatedVotes
                );
            sumVotingPowers += (newVotingPower.total() - oldTotal);
        }
    }
}
