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
