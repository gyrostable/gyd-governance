// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

library Merkle {
    struct Root {
        bytes32 _root;
    }

    function isProofValid(
        Root storage root,
        bytes32 firstNode,
        bytes32[] memory remainingNodes
    ) internal view returns (bool) {
        bytes32 node = firstNode;
        for (uint256 i = 0; i < remainingNodes.length; i++) {
            (bytes32 left, bytes32 right) = (node, remainingNodes[i]);
            if (left > right) (left, right) = (right, left);
            node = keccak256(abi.encodePacked(left, right));
        }

        return node == root._root;
    }
}
