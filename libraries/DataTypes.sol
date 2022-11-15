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
        Status status;
        ProposalAction action;
    }

    struct Vault {
        address vaultAddress;
        uint64 weight;
    }

    struct PendingWithdrawal {
        uint256 withdrawableAt;
        uint256 amount;
    }
}
