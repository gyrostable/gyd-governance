// SPDX-License-Identifier: GPL-3.0-or-later
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
