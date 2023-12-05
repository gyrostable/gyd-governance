// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../interfaces/IVotingPowerAggregator.sol";

contract MockProxy {
    address public _upgradeTo;

    IVotingPowerAggregator public votingPowerAggregator;

    function upgradeTo(address to) external {
        _upgradeTo = to;
    }

    function setVotingPowerAggregator(address _votingPowerAggregator) external {
        votingPowerAggregator = IVotingPowerAggregator(_votingPowerAggregator);
    }

    function executeCall(
        address target,
        bytes memory data
    ) external returns (bytes memory) {
        (bool success, bytes memory result) = target.call(data);
        require(success, "MockProxy: call failed");
        return result;
    }
}
