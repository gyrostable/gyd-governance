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

import "./NFTVault.sol";
import "../../libraries/DataTypes.sol";
import "../../libraries/ScaledMath.sol";
import "../../libraries/Merkle.sol";
import "../../libraries/VotingPowerHistory.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract FoundingMemberVault is NFTVault, EIP712 {
    using Merkle for Merkle.Root;
    using VotingPowerHistory for VotingPowerHistory.History;

    string internal constant _VAULT_TYPE = "FoundingMember";

    mapping(address => bool) private _claimed;

    bytes32 private immutable _TYPE_HASH =
        keccak256(
            "Proof(address account,address receiver,address delegate,uint128 multiplier,bytes32[] proof)"
        );
    Merkle.Root private merkleRoot;

    constructor(
        address _owner,
        uint256 _sumVotingPowers,
        bytes32 _merkleRoot
    ) EIP712("FoundingMemberVault", "1") NFTVault(_owner) {
        sumVotingPowers = _sumVotingPowers;
        merkleRoot = Merkle.Root(_merkleRoot);
    }

    function claimNFT(
        address nftOwner,
        address delegate,
        uint128 multiplier,
        bytes32[] calldata proof,
        bytes calldata signature
    ) external {
        require(
            multiplier >= 1e18 && multiplier <= 20e18,
            "multiplier must be greater or equal than 1e18 and lower or equal than 20e18"
        );

        bytes32 hash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _TYPE_HASH,
                    nftOwner,
                    msg.sender,
                    delegate,
                    multiplier,
                    _encodeProof(proof)
                )
            )
        );
        address claimant = ECDSA.recover(hash, signature);
        require(claimant == nftOwner, "invalid signature");

        require(!_claimed[nftOwner], "NFT already claimed");

        bytes32 node = keccak256(abi.encodePacked(nftOwner, multiplier));
        require(merkleRoot.isProofValid(node, proof), "invalid proof");

        _claimed[nftOwner] = true;

        VotingPowerHistory.Record memory current = history.currentRecord(
            msg.sender
        );
        history.updateVotingPower(
            msg.sender,
            current.baseVotingPower + ScaledMath.ONE,
            multiplier,
            current.netDelegatedVotes
        );

        if (delegate != address(0) && delegate != msg.sender) {
            _delegateVote(msg.sender, delegate, multiplier);
        }
    }

    function _encodeProof(
        bytes32[] memory proof
    ) internal pure returns (bytes32) {
        bytes memory proofB;
        for (uint256 i = 0; i < proof.length; i++) {
            proofB = bytes.concat(proofB, abi.encode(proof[i]));
        }
        return keccak256(proofB);
    }

    function getVaultType() external pure returns (string memory) {
        return _VAULT_TYPE;
    }
}
