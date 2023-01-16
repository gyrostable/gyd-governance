// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

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

    struct VaultWeight {
        address vaultAddress;
        uint256 weight;
    }

    struct Tier {
        uint64 quorum;
        uint64 proposalThreshold;
        uint64 voteThreshold;
        uint32 timeLockDuration;
        uint32 proposalLength;
        uint8 actionLevel;
    }

    struct BaseVotingPower {
        uint128 multiplier;
        uint128 base;
    }

    struct EmergencyRecoveryProposal {
        uint256 vetos;
        uint64 completesAt;
        Status status;
        bytes payload;
    }

    enum Ballot {
        UNDEFINED,
        FOR,
        AGAINST
    }

    struct Vote {
        Ballot ballot;
        uint256 votingPower;
    }

    struct VoteTotals {
        uint128 _for;
        uint128 against;
    }

    enum ProposalOutcome {
        UNDEFINED,
        QUORUM_NOT_MET,
        THRESHOLD_NOT_MET,
        SUCCESSFUL
    }
}
