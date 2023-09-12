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

import "../GovernanceManager.sol";

/// @dev testing contract that allows to execute any call instantly
contract TestingGovernanceManager is GovernanceManager {
    using Address for address;

    constructor(
        address multisig,
        IVotingPowerAggregator _votingPowerAggregator,
        ITierer _tierer
    ) GovernanceManager(multisig, _votingPowerAggregator, _tierer) {}

    function executeCall(address target, bytes calldata data) external {
        target.functionCall(data);
    }
}
