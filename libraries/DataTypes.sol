// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../interfaces/ITierStrategy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

library DataTypes {
    enum Status {
        Active,
        Rejected,
        Queued,
        Executed
    }

    struct ProposalAction {
        address target;
        bytes data;
    }

    struct Proposal {
        uint64 createdAt;
        uint64 executableAt;
        uint64 votingEndsAt;
        uint64 voteThreshold;
        uint64 quorum;
        uint24 id;
        address proposer;
        Status status;
        ProposalAction action;
    }

    struct PendingWithdrawal {
        uint256 id;
        uint256 withdrawableAt;
        uint256 amount;
        address to;
        address delegate;
    }

    struct VaultWeightConfiguration {
        address vaultAddress;
        uint256 initialWeight;
        uint256 targetWeight;
    }

    struct VaultWeight {
        address vaultAddress;
        uint256 currentWeight;
        uint256 initialWeight;
        uint256 targetWeight;
    }

    struct VaultVotingPower {
        address vaultAddress;
        uint256 votingPower;
    }

    struct Tier {
        uint64 quorum;
        uint64 proposalThreshold;
        uint64 voteThreshold;
        uint32 timeLockDuration;
        uint32 proposalLength;
        uint8 actionLevel;
    }

    struct EmergencyRecoveryProposal {
        uint64 completesAt;
        Status status;
        bytes payload;
        EnumerableMap.AddressToUintMap vetos;
    }

    enum Ballot {
        UNDEFINED,
        FOR,
        AGAINST,
        ABSTAIN
    }

    struct Vote {
        Ballot ballot;
        VaultVotingPower[] vaults;
    }

    struct VoteTotals {
        VaultVotingPower[] _for;
        VaultVotingPower[] against;
        VaultVotingPower[] abstentions;
    }

    enum ProposalOutcome {
        UNDEFINED,
        QUORUM_NOT_MET,
        THRESHOLD_NOT_MET,
        SUCCESSFUL
    }

    struct LimitUpgradeabilityParameters {
        uint8 actionLevelThreshold;
        uint256 emaThreshold;
        ITierStrategy tierStrategy;
    }
}
