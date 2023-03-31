// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./NFTVault.sol";
import "../../libraries/DataTypes.sol";
import "../../libraries/ScaledMath.sol";
import "../../libraries/Merkle.sol";
import "../../libraries/VotingPowerHistory.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract FoundingFrogVault is NFTVault, EIP712 {
    using Merkle for Merkle.Root;
    using VotingPowerHistory for VotingPowerHistory.History;

    mapping(address => address) private _claimed;

    bytes32 private immutable _TYPE_HASH =
        keccak256("Proof(address account,uint128 multiplier,bytes32[] proof)");
    Merkle.Root private merkleRoot;

    constructor(
        address _owner,
        uint256 _sumVotingPowers,
        bytes32 _merkleRoot
    ) EIP712("FoundingFrogVault", "1") NFTVault(_owner) {
        sumVotingPowers = _sumVotingPowers;
        merkleRoot = Merkle.Root(_merkleRoot);
    }

    function claimNFT(
        address nftOwner,
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
                    multiplier,
                    _encodeProof(proof)
                )
            )
        );
        address claimant = ECDSA.recover(hash, signature);
        require(claimant == nftOwner, "invalid signature");

        require(_claimed[nftOwner] == address(0), "NFT already claimed");

        bytes32 node = keccak256(abi.encodePacked(nftOwner, multiplier));
        require(merkleRoot.isProofValid(node, proof), "invalid proof");

        _claimed[nftOwner] = msg.sender;

        VotingPowerHistory.Record memory current = history.currentRecord(
            msg.sender
        );
        history.updateVotingPower(
            msg.sender,
            current.baseVotingPower + ScaledMath.ONE,
            multiplier,
            current.netDelegatedVotes
        );
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
}
