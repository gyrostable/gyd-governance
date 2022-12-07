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
        uint24 id;
        address proposer;
        uint64 createdAt;
        uint64 executableAt;
        uint64 votingEndsAt;
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
        uint32 timeLockDuration;
        uint32 proposalLength;
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
        uint256 _for;
        uint256 against;
        uint256 combined;
    }

    enum ProposalOutcome {
        UNDEFINED,
        QUORUM_NOT_MET,
        THRESHOLD_NOT_MET,
        SUCCESSFUL
    }
}
