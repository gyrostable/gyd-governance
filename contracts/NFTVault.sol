// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../interfaces/IVault.sol";
import "../interfaces/IDelegator.sol";
import "./access/ImmutableOwner.sol";
import "../libraries/DataTypes.sol";
import "../libraries/Delegations.sol";
import "../libraries/BaseVotingPower.sol";

abstract contract NFTVault is IVault, IDelegator, ImmutableOwner {
    using BaseVotingPower for DataTypes.BaseVotingPower;
    using Delegations for Delegations.Delegations;

    Delegations.Delegations internal delegations;

    // A user's own voting power, excluding delegations either to or from the user.
    // This caches voting power and stores voting power mutations.
    mapping(address => DataTypes.BaseVotingPower) internal ownVotingPowers;

    uint256 internal sumVotingPowers;

    constructor(address _owner) ImmutableOwner(_owner) {}

    function delegateVote(address _delegate, uint256 _amount) external {
        delegations.delegateVote(
            msg.sender,
            _delegate,
            _amount,
            ownVotingPowers[msg.sender].total()
        );
    }

    function undelegateVote(address _delegate, uint256 _amount) external {
        delegations.undelegateVote(msg.sender, _delegate, _amount);
    }

    function changeDelegate(
        address _oldDelegate,
        address _newDelegate,
        uint256 _amount
    ) external {
        delegations.undelegateVote(msg.sender, _oldDelegate, _amount);
        delegations.delegateVote(
            msg.sender,
            _newDelegate,
            _amount,
            ownVotingPowers[msg.sender].total()
        );
    }

    function getRawVotingPower(address user) external view returns (uint256) {
        return
            uint256(
                int256(ownVotingPowers[user].total()) +
                    delegations.netDelegatedVotes(user)
            );
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
            DataTypes.BaseVotingPower storage oldVotingPower = ownVotingPowers[
                users[i]
            ];
            require(
                oldVotingPower.base >= 1e18,
                "all users must have at least 1 NFT"
            );
            require(
                oldVotingPower.multiplier < _multiplier,
                "cannot decrease voting power"
            );

            uint256 oldTotal = oldVotingPower.total();
            oldVotingPower.multiplier = _multiplier;
            sumVotingPowers += (oldVotingPower.total() - oldTotal);
        }
    }
}
