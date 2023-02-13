// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../libraries/VotingPowerHistory.sol";

contract VotingPowerHistoryLibrary {
    using VotingPowerHistory for VotingPowerHistory.History;
    using VotingPowerHistory for VotingPowerHistory.Record;

    VotingPowerHistory.History internal history;

    function binarySearch(
        address for_,
        uint256 at
    ) external view returns (bool found, VotingPowerHistory.Record memory) {
        return VotingPowerHistory.binarySearch(history.votes[for_], at);
    }

    function updateVotingPower(
        address for_,
        uint256 baseVotingPower,
        uint256 multiplier,
        int256 netDelegatedVotes
    ) external {
        history.updateVotingPower(
            for_,
            baseVotingPower,
            multiplier,
            netDelegatedVotes
        );
    }

    function getVotingPower(
        address for_,
        uint256 at
    ) external view returns (uint256) {
        return history.getVotingPower(for_, at);
    }
}
