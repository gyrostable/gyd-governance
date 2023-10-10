// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@gnosis.pm/safe-contracts/contracts/base/GuardManager.sol";
import "@gnosis.pm/safe-contracts/contracts/base/OwnerManager.sol";
import "@gnosis.pm/safe-contracts/contracts/base/ModuleManager.sol";
import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "../../libraries/Errors.sol";

contract NoSafeManagementByMultisig is Guard {
    address private safe;
    address private module;

    bytes4[7] private forbiddenSelectors = [
        // Prevent the multisig from changing the owners/threshold associated
        // with the contract. Only governance should be allowed to change these.
        OwnerManager.addOwnerWithThreshold.selector,
        OwnerManager.removeOwner.selector,
        OwnerManager.swapOwner.selector,
        OwnerManager.changeThreshold.selector,
        // Prevent the multisig from disabling the Guard, which enforces the restrictions
        // above.
        GuardManager.setGuard.selector,
        // Prevent the multisig from enabling a new module which could
        // bypass the above restrictions, or from removing existing modules,
        // such as the one which allows governance to change signers.
        ModuleManager.enableModule.selector,
        ModuleManager.disableModule.selector
    ];

    constructor(address _safe, address _module) {
        safe = _safe;
        module = _module;
    }

    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory,
        address
    ) external {
        bytes4 selector = _getSelector(data);
        // There's no point in checking `msg.sender` here, since msg.sender will always
        // be the safe contract.
        // Calls from the module don't go through the guard, and so wouldn't be
        // caught by this if statement.
        bool isCallForbidden = false;
        for (uint256 i = 0; i < forbiddenSelectors.length; i++) {
            if (selector == forbiddenSelectors[i]) {
                isCallForbidden = true;
                break;
            }
        }

        if (to == safe && isCallForbidden) {
            revert Errors.NotAuthorized(msg.sender, module);
        }
    }

    function checkAfterExecution(bytes32, bool) external {
        return;
    }

    function _getSelector(
        bytes memory _calldata
    ) internal pure returns (bytes4 out) {
        assembly {
            out := and(
                mload(add(_calldata, 32)),
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000
            )
        }
    }
}
