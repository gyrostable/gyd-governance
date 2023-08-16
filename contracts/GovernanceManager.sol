// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../libraries/DataTypes.sol";
import "../libraries/ScaledMath.sol";
import "../libraries/VaultsSnapshot.sol";
import "../libraries/Errors.sol";

import "../interfaces/IVault.sol";
import "../interfaces/IVotingPowerAggregator.sol";
import "../interfaces/ITierer.sol";
import "../interfaces/ITierStrategy.sol";
import "../interfaces/IWrappedERC20WithEMA.sol";

contract GovernanceManager is Initializable {
    using Address for address;
    using ScaledMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using VaultsSnapshot for DataTypes.VaultSnapshot[];

    IVotingPowerAggregator public immutable votingPowerAggregator;
    ITierer public immutable tierer;

    IWrappedERC20WithEMA public wGYD;
    DataTypes.LimitUpgradeabilityParameters public limitUpgradeabilityParams;

    uint24 public proposalsCount;

    EnumerableSet.UintSet internal _activeProposals;
    EnumerableSet.UintSet internal _timelockedProposals;
    mapping(uint24 => DataTypes.Proposal) internal _proposals;
    mapping(uint24 => DataTypes.VaultSnapshot[]) internal _vaultSnapshots;

    mapping(address => mapping(uint24 => DataTypes.Ballot)) internal _votes;
    mapping(uint24 => mapping(DataTypes.Ballot => EnumerableMap.AddressToUintMap))
        internal _totals;

    modifier onlySelf() {
        if (msg.sender != address(this))
            revert Errors.NotAuthorized(msg.sender, address(this));
        _;
    }

    constructor(
        IVotingPowerAggregator _votingPowerAggregator,
        ITierer _tierer
    ) {
        votingPowerAggregator = _votingPowerAggregator;
        tierer = _tierer;
    }

    function initializeUpgradeabilityParams(
        IWrappedERC20WithEMA _wGYD,
        DataTypes.LimitUpgradeabilityParameters memory _params
    ) external initializer onlySelf {
        wGYD = _wGYD;
        limitUpgradeabilityParams = _params;
    }

    event ProposalCreated(
        uint24 indexed id,
        address proposer,
        DataTypes.ProposalAction[] actions
    );

    function createProposal(
        DataTypes.ProposalAction[] calldata actions
    ) external {
        require(actions.length > 0, "cannot create a proposal with no actions");

        // Determine the tier associated with this proposal by taking the tier of the most impactful
        // action, determined by the tier's actionLevel parameter.
        DataTypes.ProposalAction memory action = actions[0];
        DataTypes.Tier memory tier = tierer.getTier(action.target, action.data);
        for (uint256 i = 1; i < actions.length; i++) {
            DataTypes.Tier memory currentTier = tierer.getTier(
                actions[i].target,
                actions[i].data
            );
            if (currentTier.actionLevel > tier.actionLevel) {
                action = actions[i];
                tier = currentTier;
            }
        }

        // If a sufficiently large amount of GYD is wrapped, this signifies that holders
        // are happy with the system and are against further high-level upgrades.
        // As a result, we should apply a higher tier if the proposed action has big impacts.
        if (
            address(wGYD) != address(0) &&
            wGYD.wrappedPctEMA() > limitUpgradeabilityParams.emaThreshold &&
            tier.actionLevel > limitUpgradeabilityParams.actionLevelThreshold
        ) {
            tier = limitUpgradeabilityParams.tierStrategy.getTier(action.data);
        }

        DataTypes.VaultVotingPower[] memory rawPower = votingPowerAggregator
            .getVotingPower(msg.sender, block.timestamp - 1);
        uint256 votingPowerPct = votingPowerAggregator
            .calculateWeightedPowerPct(rawPower);
        require(
            votingPowerPct > tier.proposalThreshold,
            "proposer doesn't have enough voting power to propose this action"
        );

        uint64 createdAt = uint64(block.timestamp);
        uint64 votingEndsAt = createdAt + tier.proposalLength;
        uint64 executableAt = votingEndsAt + tier.timeLockDuration;

        DataTypes.Proposal storage p = _proposals[proposalsCount];
        p.id = proposalsCount;
        p.proposer = msg.sender;
        p.createdAt = createdAt;
        p.votingEndsAt = votingEndsAt;
        p.executableAt = executableAt;
        p.status = DataTypes.Status.Active;
        p.quorum = tier.quorum;
        p.voteThreshold = tier.voteThreshold;

        for (uint256 i = 0; i < actions.length; i++) {
            p.actions.push(actions[i]);
        }

        votingPowerAggregator.createVaultsSnapshot().persist(
            _vaultSnapshots[p.id]
        );

        proposalsCount = p.id + 1;
        _activeProposals.add(uint256(p.id));

        emit ProposalCreated(p.id, p.proposer, actions);
    }

    event VoteCast(
        uint24 indexed proposalId,
        address voter,
        DataTypes.Ballot vote
    );

    function vote(uint24 proposalId, DataTypes.Ballot ballot) external {
        DataTypes.Proposal storage proposal = _proposals[proposalId];
        require(proposal.createdAt != 0, "proposal does not exist");
        require(block.timestamp > proposal.createdAt, "voting has not started");

        require(
            proposal.votingEndsAt > uint64(block.timestamp),
            "voting is closed on this proposal"
        );

        require(
            ballot != DataTypes.Ballot.Undefined,
            "ballot must be cast For, Against, or Abstain"
        );

        DataTypes.VaultSnapshot[] memory vaultSnapshots = _vaultSnapshots[
            proposalId
        ];

        DataTypes.VaultVotingPower[] memory uvp = votingPowerAggregator
            .getVotingPower(
                msg.sender,
                proposal.createdAt,
                _vaultAddresses(vaultSnapshots)
            );

        DataTypes.Ballot existingVote = _votes[msg.sender][proposalId];

        bool isNewVote = existingVote == DataTypes.Ballot.Undefined;
        for (uint256 i = 0; i < uvp.length; i++) {
            DataTypes.VaultVotingPower memory vvp = uvp[i];

            // cancel out the previous vote if it was cast
            if (!isNewVote) {
                (, uint256 prevBallotTotal) = _totals[proposalId][existingVote]
                    .tryGet(vvp.vaultAddress);
                _totals[proposalId][existingVote].set(
                    vvp.vaultAddress,
                    prevBallotTotal - vvp.votingPower
                );
            }

            (, uint256 newBallotTotal) = _totals[proposalId][ballot].tryGet(
                vvp.vaultAddress
            );
            _totals[proposalId][ballot].set(
                vvp.vaultAddress,
                newBallotTotal + vvp.votingPower
            );
        }

        // Then update the record of this user's vote to the latest ballot and voting power
        _votes[msg.sender][proposalId] = ballot;

        emit VoteCast(proposalId, msg.sender, ballot);
    }

    function getVoteTotals(
        uint24 proposalId
    ) external view returns (DataTypes.VoteTotals memory) {
        return _toVoteTotals(_totals[proposalId]);
    }

    function _toVoteTotals(
        mapping(DataTypes.Ballot => EnumerableMap.AddressToUintMap)
            storage totals
    ) internal view returns (DataTypes.VoteTotals memory) {
        EnumerableMap.AddressToUintMap storage forVotingPower = totals[
            DataTypes.Ballot.For
        ];
        DataTypes.VaultVotingPower[] memory forTotals = _toVotingPowers(
            forVotingPower
        );

        EnumerableMap.AddressToUintMap storage againstVotingPower = totals[
            DataTypes.Ballot.Against
        ];
        DataTypes.VaultVotingPower[] memory againstTotals = _toVotingPowers(
            againstVotingPower
        );

        EnumerableMap.AddressToUintMap storage abstentionsVotingPower = totals[
            DataTypes.Ballot.Abstain
        ];
        DataTypes.VaultVotingPower[] memory abstentionsTotals = _toVotingPowers(
            abstentionsVotingPower
        );

        return
            DataTypes.VoteTotals({
                _for: forTotals,
                against: againstTotals,
                abstentions: abstentionsTotals
            });
    }

    event ProposalTallied(
        uint24 indexed proposalId,
        DataTypes.Status status,
        DataTypes.ProposalOutcome outcome
    );

    function tallyVote(uint24 proposalId) external {
        DataTypes.Proposal storage proposal = _proposals[proposalId];
        require(proposal.createdAt != 0, "proposal does not exist");

        require(
            _activeProposals.contains(uint256(proposalId)),
            "proposal is not currently active"
        );

        require(
            uint64(block.timestamp) > proposal.votingEndsAt,
            "voting is ongoing for this proposal"
        );

        (
            uint256 forTotalPct,
            uint256 againstTotalPct,
            uint256 abstentionsTotalPct
        ) = _getCurrentPercentages(proposal);

        uint256 combinedPct = forTotalPct +
            againstTotalPct +
            abstentionsTotalPct;
        if (combinedPct < proposal.quorum) {
            proposal.status = DataTypes.Status.Rejected;
            _activeProposals.remove(uint256(proposalId));
            emit ProposalTallied(
                proposalId,
                proposal.status,
                DataTypes.ProposalOutcome.QuorumNotMet
            );
            return;
        }

        uint256 result = 0;
        if (forTotalPct + againstTotalPct > 0) {
            result = forTotalPct.divDown(forTotalPct + againstTotalPct);
        }
        DataTypes.ProposalOutcome outcome = DataTypes.ProposalOutcome.Undefined;
        if (result >= proposal.voteThreshold) {
            proposal.status = DataTypes.Status.Queued;
            outcome = DataTypes.ProposalOutcome.Successful;
            _timelockedProposals.add(uint256(proposalId));
        } else {
            proposal.status = DataTypes.Status.Rejected;
            outcome = DataTypes.ProposalOutcome.ThresholdNotMet;
        }
        _activeProposals.remove(uint256(proposalId));
        emit ProposalTallied(proposalId, proposal.status, outcome);
    }

    function getCurrentPercentages(
        uint24 proposalId
    ) external view returns (uint256 for_, uint256 against, uint256 abstain) {
        DataTypes.Proposal storage proposal = _proposals[proposalId];
        require(proposal.createdAt != 0, "proposal does not exist");
        return _getCurrentPercentages(proposal);
    }

    function _getCurrentPercentages(
        DataTypes.Proposal storage proposal
    ) internal view returns (uint256 for_, uint256 against, uint256 abstain) {
        DataTypes.VaultSnapshot[] memory snapshot = _vaultSnapshots[
            proposal.id
        ];
        mapping(DataTypes.Ballot => EnumerableMap.AddressToUintMap)
            storage propTotals = _totals[proposal.id];
        for_ = snapshot.getBallotPercentage(propTotals[DataTypes.Ballot.For]);
        against = snapshot.getBallotPercentage(
            propTotals[DataTypes.Ballot.Against]
        );
        abstain = snapshot.getBallotPercentage(
            propTotals[DataTypes.Ballot.Abstain]
        );
    }

    function _toVotingPowers(
        EnumerableMap.AddressToUintMap storage map
    ) internal view returns (DataTypes.VaultVotingPower[] memory) {
        DataTypes.VaultVotingPower[]
            memory vvps = new DataTypes.VaultVotingPower[](map.length());
        for (uint256 i = 0; i < map.length(); i++) {
            (address key, uint256 value) = map.at(i);
            vvps[i] = DataTypes.VaultVotingPower({
                vaultAddress: key,
                votingPower: value
            });
        }

        return vvps;
    }

    event ProposalExecuted(uint24 indexed proposalId);

    function executeProposal(uint24 proposalId) external {
        DataTypes.Proposal storage proposal = _proposals[proposalId];
        if (proposal.createdAt == uint64(0)) {
            revert("proposal does not exist");
        }

        require(
            _timelockedProposals.contains(uint256(proposalId)) &&
                uint64(block.timestamp) > proposal.executableAt,
            "proposal must be queued and ready to execute"
        );

        for (uint256 i = 0; i < proposal.actions.length; i++) {
            proposal.actions[i].target.functionCall(
                proposal.actions[i].data,
                "proposal execution failed"
            );
        }
        proposal.status = DataTypes.Status.Executed;
        _timelockedProposals.remove(uint256(proposalId));
        emit ProposalExecuted(proposalId);
    }

    function getBallot(
        address voter,
        uint24 proposalId
    ) external view returns (DataTypes.Ballot) {
        return _votes[voter][proposalId];
    }

    function updateLimitUpgradeabilityParams(
        DataTypes.LimitUpgradeabilityParameters memory _params
    ) external onlySelf {
        limitUpgradeabilityParams = _params;
    }

    function listActiveProposals()
        external
        view
        returns (DataTypes.Proposal[] memory)
    {
        return _listProposals(_activeProposals.values());
    }

    function listTimelockedProposals()
        external
        view
        returns (DataTypes.Proposal[] memory)
    {
        return _listProposals(_timelockedProposals.values());
    }

    function _listProposals(
        uint256[] memory ids
    ) internal view returns (DataTypes.Proposal[] memory) {
        uint256 len = ids.length;
        DataTypes.Proposal[] memory proposals = new DataTypes.Proposal[](len);
        for (uint256 i = 0; i < len; i++) {
            proposals[i] = _proposals[uint24(ids[i])];
        }
        return proposals;
    }

    function _vaultAddresses(
        DataTypes.VaultSnapshot[] memory vaultSnapshots
    ) internal pure returns (address[] memory) {
        uint256 len = vaultSnapshots.length;
        address[] memory vaultAddresses = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            vaultAddresses[i] = vaultSnapshots[i].vaultAddress;
        }
        return vaultAddresses;
    }
}
