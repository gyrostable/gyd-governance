// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../interfaces/IVotingPowersUpdater.sol";
import "../libraries/Merkle.sol";
import "./access/ImmutableOwner.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract CouncillorNFT is
    ERC721Enumerable,
    ImmutableOwner,
    EIP712,
    Initializable
{
    using Merkle for Merkle.Root;

    constructor(
        string memory _name,
        string memory _ticker,
        address _owner,
        uint16 _maxSupply,
        bytes32 _merkleRoot
    ) ERC721(_name, _ticker) ImmutableOwner(_owner) EIP712(_name, "1") {
        maxSupply = _maxSupply;
        merkleRoot = Merkle.Root(_merkleRoot);
    }

    IVotingPowersUpdater private vault;
    uint16 private tokenId;
    uint16 public maxSupply;
    bool private transfersAllowed;

    Merkle.Root private merkleRoot;
    bytes32 private immutable _TYPE_HASH =
        keccak256("Proof(address to,bytes32[] proof)");

    mapping(address => bool) private _claimed;

    function initializeGovernanceVault(address _vault) public initializer {
        vault = IVotingPowersUpdater(_vault);
    }

    function setTransfersAllowed(bool _transfersAllowed) public onlyOwner {
        transfersAllowed = _transfersAllowed;
    }

    function mint(
        address to,
        bytes32[] calldata proof,
        bytes calldata signature
    ) public {
        _requireValidProof(to, proof, signature);

        require(!_claimed[to], "user has already claimed NFT");
        require(
            tokenId < maxSupply,
            "mint error: supply cap would be exceeded"
        );

        _mint(to, tokenId);
        tokenId++;

        _claimed[to] = true;

        vault.updateBaseVotingPower(to, 1e18);
    }

    function _requireValidProof(
        address to,
        bytes32[] calldata proof,
        bytes calldata signature
    ) internal view {
        if (msg.sender == owner) {
            return;
        }

        bytes32 hash = _hashTypedDataV4(
            keccak256(abi.encode(_TYPE_HASH, to, _encodeProof(proof)))
        );
        address claimant = ECDSA.recover(hash, signature);

        require(claimant == to, "invalid signature");

        bytes32 node = keccak256(abi.encodePacked(to));
        require(merkleRoot.isProofValid(node, proof), "invalid proof");
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

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override {
        // `from == address(0)` in the case of mints.
        // We want to revert unless we're minting or transfers have been enabled.
        // In any case, we don't want to transfer the associated voting power.
        require(from == address(0) || transfersAllowed, "cannot transfer NFT");
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }
}
