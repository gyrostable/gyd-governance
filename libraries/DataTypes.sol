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

import "../interfaces/ITierStrategy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

library DataTypes {
    enum Status {
        Undefined,
        Active,
        Rejected,
        Queued,
        Executed,
        Vetoed
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
        uint16 id;
        uint8 actionLevel;
        address proposer;
        Status status;
        ProposalAction[] actions;
    }

    struct PendingWithdrawal {
        uint256 id;
        uint256 withdrawableAt;
        uint256 amount;
        address to;
        address delegate;
    }

    struct VaultWeightSchedule {
        VaultWeightConfiguration[] vaults;
        uint256 startsAt;
        uint256 endsAt;
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
        uint64 createdAt;
        uint64 completesAt;
        Status status;
        bytes payload;
        EnumerableMap.AddressToUintMap vetos;
    }

    enum Ballot {
        Undefined,
        For,
        Against,
        Abstain
    }

    struct VoteTotals {
        VaultVotingPower[] _for;
        VaultVotingPower[] against;
        VaultVotingPower[] abstentions;
    }

    struct VaultSnapshot {
        address vaultAddress;
        uint256 weight;
        uint256 totalVotingPower;
    }

    enum ProposalOutcome {
        Undefined,
        QuorumNotMet,
        ThresholdNotMet,
        Successful
    }

    struct LimitUpgradeabilityParameters {
        uint8 actionLevelThreshold;
        uint256 emaThreshold;
        uint256 minBGYDSupply;
        ITierStrategy tierStrategy;
    }

    struct Delegation {
        address delegate;
        uint256 amount;
    }
}
