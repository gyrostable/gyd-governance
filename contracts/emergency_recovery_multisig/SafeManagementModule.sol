// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "../access/GovernanceOnly.sol";

contract SafeManagementModule is GovernanceOnly {
    GnosisSafe private safe;

    constructor(
        address payable _safe,
        address _governance
    ) GovernanceOnly(_governance) {
        safe = GnosisSafe(_safe);
    }

    function setSigners(
        address[] calldata signers,
        uint256 threshold
    ) external governanceOnly {
        address[] memory oldOwners = safe.getOwners();
        if (signers.length >= oldOwners.length) {
            // The new list is longer the old list, therefore:
            // - we swap old for new up until the length of the old list
            // - and add excess members of the new list
            address previousOwner = address(0x1); // head of list
            for (uint256 i = 0; i < oldOwners.length; i++) {
                _swapOwner(previousOwner, oldOwners[i], signers[i]);
                previousOwner = signers[i];
            }

            for (uint256 i = oldOwners.length; i < signers.length; i++) {
                _addOwnerWithThreshold(signers[i], threshold);
            }
        } else {
            // The old list is longer the new list, therefore:
            // - we swap old for new up until the length of the new list
            // - and remove excess members from the old list.
            address previousOwner = address(0x1); // head of list
            for (uint256 i = 0; i < signers.length; i++) {
                _swapOwner(previousOwner, oldOwners[i], signers[i]);
                previousOwner = signers[i];
            }

            for (uint256 i = signers.length; i < oldOwners.length; i++) {
                _removeOwner(previousOwner, oldOwners[i], threshold);
            }
        }
    }

    function swapOwner(
        address prevOwner,
        address oldOwner,
        address newOwner
    ) external governanceOnly {
        _swapOwner(prevOwner, oldOwner, newOwner);
    }

    function _swapOwner(
        address prevOwner,
        address oldOwner,
        address newOwner
    ) internal {
        bytes memory data = abi.encodeCall(
            OwnerManager.swapOwner,
            (prevOwner, oldOwner, newOwner)
        );
        safe.execTransactionFromModule(
            address(safe),
            0,
            data,
            Enum.Operation.Call
        );
    }

    function removeOwner(
        address prevOwner,
        address oldOwner,
        uint256 _threshold
    ) external governanceOnly {
        _removeOwner(prevOwner, oldOwner, _threshold);
    }

    function _removeOwner(
        address prevOwner,
        address oldOwner,
        uint256 _threshold
    ) internal {
        bytes memory data = abi.encodeCall(
            OwnerManager.removeOwner,
            (prevOwner, oldOwner, _threshold)
        );
        safe.execTransactionFromModule(
            address(safe),
            0,
            data,
            Enum.Operation.Call
        );
    }

    function addOwnerWithThreshold(
        address owner,
        uint256 _threshold
    ) external governanceOnly {
        _addOwnerWithThreshold(owner, _threshold);
    }

    function _addOwnerWithThreshold(
        address owner,
        uint256 _threshold
    ) internal {
        bytes memory data = abi.encodeCall(
            OwnerManager.addOwnerWithThreshold,
            (owner, _threshold)
        );
        safe.execTransactionFromModule(
            address(safe),
            0,
            data,
            Enum.Operation.Call
        );
    }

    function changeThreshold(uint256 threshold) external governanceOnly {
        bytes memory data = abi.encodeCall(
            OwnerManager.changeThreshold,
            threshold
        );
        safe.execTransactionFromModule(
            address(safe),
            0,
            data,
            Enum.Operation.Call
        );
    }

    function setGuard(address guard) external governanceOnly {
        bytes memory data = abi.encodeCall(GuardManager.setGuard, guard);
        safe.execTransactionFromModule(
            address(safe),
            0,
            data,
            Enum.Operation.Call
        );
    }

    function enableModule(address module) external governanceOnly {
        bytes memory data = abi.encodeCall(ModuleManager.enableModule, module);
        safe.execTransactionFromModule(
            address(safe),
            0,
            data,
            Enum.Operation.Call
        );
    }

    function disableModule(
        address prevModule,
        address module
    ) external governanceOnly {
        bytes memory data = abi.encodeCall(
            ModuleManager.disableModule,
            (prevModule, module)
        );
        safe.execTransactionFromModule(
            address(safe),
            0,
            data,
            Enum.Operation.Call
        );
    }
}
