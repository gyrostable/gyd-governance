// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
