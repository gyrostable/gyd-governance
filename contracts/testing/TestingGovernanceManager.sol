// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "../GovernanceManager.sol";

/// @dev testing contract that allows to execute any call instantly
contract TestingGovernanceManager is GovernanceManager {
    using Address for address;

    constructor(
        IVotingPowerAggregator _votingPowerAggregator,
        ITierer _tierer
    ) GovernanceManager(_votingPowerAggregator, _tierer) {}

    function executeCall(address target, bytes calldata data) external {
        target.functionCall(data);
    }
}
