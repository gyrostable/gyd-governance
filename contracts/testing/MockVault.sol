// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../vaults/BaseVault.sol";
import "../../interfaces/IVault.sol";
import "../../interfaces/IDelegatingVault.sol";
import "../../libraries/VotingPowerHistory.sol";

contract MockVault is BaseVault, IDelegatingVault {
    using VotingPowerHistory for VotingPowerHistory.History;

    uint256 public rawVotingPower;
    uint256 public totalRawVotingPower;

    VotingPowerHistory.History internal history;

    constructor(uint256 _rawVotingPower, uint256 _totalRawVotingPower) {
        rawVotingPower = _rawVotingPower;
        totalRawVotingPower = _totalRawVotingPower;
    }

    function delegateVote(address _delegate, uint256 _amount) external {
        history.delegateVote(msg.sender, _delegate, _amount);
    }

    function undelegateVote(address _delegate, uint256 _amount) external {
        history.undelegateVote(msg.sender, _delegate, _amount);
    }

    function updateVotingPower(address user, uint256 amount) external {
        VotingPowerHistory.Record memory currentVotingPower = history
            .currentRecord(user);
        history.updateVotingPower(
            user,
            amount,
            currentVotingPower.multiplier,
            currentVotingPower.netDelegatedVotes
        );
    }

    function changeDelegate(
        address _oldDelegate,
        address _newDelegate,
        uint256 _amount
    ) external {
        history.undelegateVote(msg.sender, _oldDelegate, _amount);
        history.delegateVote(msg.sender, _newDelegate, _amount);
    }

    function getRawVotingPower(
        address user,
        uint256 timestamp
    ) public view override returns (uint256) {
        uint256 power = history.getVotingPower(user, timestamp);
        return power == 0 ? rawVotingPower : power;
    }

    function setRawVotingPower(uint256 power) external {
        rawVotingPower = power;
    }

    function setTotalRawVotingPower(uint256 totalPower) external {
        totalRawVotingPower = totalPower;
    }

    function getTotalRawVotingPower() public view override returns (uint256) {
        return totalRawVotingPower;
    }
}
