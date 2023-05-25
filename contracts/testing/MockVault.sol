// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../vaults/BaseVault.sol";
import "../../interfaces/IVault.sol";
import "../../interfaces/IDelegatingVault.sol";
import "../../libraries/VotingPowerHistory.sol";

contract MockVault is BaseVault, IDelegatingVault {
    using VotingPowerHistory for VotingPowerHistory.History;
    using VotingPowerHistory for VotingPowerHistory.Record;
    using ScaledMath for uint256;

    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public rawVotingPower;
    uint256 public totalRawVotingPower;

    VotingPowerHistory.History internal history;

    EnumerableSet.AddressSet internal _admins;

    modifier onlyAdmin() {
        require(_admins.contains(msg.sender), "only admin");
        _;
    }

    constructor() {
        _admins.add(msg.sender);
    }

    function addAdmin(address _admin) external onlyAdmin {
        _admins.add(_admin);
    }

    function listAdmins() external view returns (address[] memory) {
        return _admins.values();
    }

    function delegateVote(address _delegate, uint256 _amount) external {
        history.delegateVote(msg.sender, _delegate, _amount);
    }

    function undelegateVote(address _delegate, uint256 _amount) external {
        history.undelegateVote(msg.sender, _delegate, _amount);
    }

    function updateVotingPower(
        address user,
        uint256 amount
    ) external onlyAdmin {
        VotingPowerHistory.Record memory currentVotingPower = history
            .currentRecord(user);
        totalRawVotingPower -= currentVotingPower.multiplier.mulDown(
            currentVotingPower.baseVotingPower
        );
        history.updateVotingPower(
            user,
            amount,
            currentVotingPower.multiplier,
            currentVotingPower.netDelegatedVotes
        );
        totalRawVotingPower += currentVotingPower.multiplier.mulDown(amount);
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
        return history.getVotingPower(user, timestamp);
    }

    function getTotalRawVotingPower() public view override returns (uint256) {
        return totalRawVotingPower;
    }
}
