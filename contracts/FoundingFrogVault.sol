// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../contracts/NFTVault.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract FoundingFrogVault is NFTVault, EIP712 {
    mapping(address => address) private _claimed;

    bytes32 private immutable _TYPE_HASH =
        keccak256("Proof(address owner,bytes32[] elements)");
    bytes32 private merkleRoot;

    constructor(
        address _owner,
        uint256 _sumVotingPowers,
        bytes32 _merkleRoot
    ) EIP712("FoundingFrogVault", "1") NFTVault(_owner) {
        sumVotingPowers = _sumVotingPowers;
        merkleRoot = _merkleRoot;
    }

    function claimNFT(
        address owner,
        bytes32[] calldata proof,
        bytes calldata signature
    ) external {
        bytes32 hash = _hashTypedDataV4(
            keccak256(abi.encode(_TYPE_HASH, owner, proof))
        );
        address claimant = ECDSA.recover(hash, signature);
        require(claimant == owner, "invalid signature");

        require(_claimed[owner] == address(0), "NFT already claimed");

        require(_isProofValid(owner, proof), "invalid proof");

        _claimed[owner] = msg.sender;

        DataTypes.BaseVotingPower storage ovp = ownVotingPowers[msg.sender];
        ovp.base += 1;
        if (ovp.multiplier == 0) {
            ovp.multiplier = 1;
        }
        sumVotingPowers += ovp.multiplier - 1;
    }

    function _isProofValid(
        address owner,
        bytes32[] memory proof
    ) internal view returns (bool) {
        bytes32 node = keccak256(abi.encodePacked(owner));
        for (uint256 i = 0; i < proof.length; i++) {
            (bytes32 left, bytes32 right) = (node, proof[i]);
            if (left > right) (left, right) = (right, left);
            node = keccak256(abi.encodePacked(left, right));
        }

        return node == merkleRoot;
    }
}
