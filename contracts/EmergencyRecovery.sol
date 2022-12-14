// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./access/GovernanceOnly.sol";
import "../libraries/DataTypes.sol";
import "../libraries/ScaledMath.sol";
import "../interfaces/IVotingPowerAggregator.sol";

contract EmergencyRecovery is GovernanceOnly {
    using ScaledMath for uint256;

    address public safeAddress;
    uint64 public sunsetAt;
    uint256 public vetoThreshold;
    uint64 public timelockDuration;

    string private UPGRADE_TO_SIG = "upgradeTo(address)";

    mapping(uint32 => DataTypes.EmergencyRecoveryProposal) private proposals;

    mapping(uint32 => mapping(address => uint256)) private vetos;

    uint32 private currentProposalCount;

    IVotingPowerAggregator private votingAggregator;

    constructor(
        address _governance,
        address _safeAddress,
        address _votingAggregator,
        uint64 _sunsetAt,
        uint256 _vetoThreshold,
        uint64 _timelockDuration
    ) GovernanceOnly(_governance) {
        safeAddress = _safeAddress;
        votingAggregator = IVotingPowerAggregator(_votingAggregator);
        sunsetAt = _sunsetAt;
        vetoThreshold = _vetoThreshold;
        timelockDuration = _timelockDuration;
    }

    modifier onlyFromSafe() {
        if (msg.sender != safeAddress)
            revert Errors.NotAuthorized(msg.sender, safeAddress);
        _;
    }

    modifier notSunset() {
        require(
            sunsetAt > uint64(block.timestamp),
            "emergency recovery is sunset"
        );
        _;
    }

    event UpgradeProposed(uint32 proposalId, bytes payload);

    function startGovernanceUpgrade(
        address newUnderlying
    ) external onlyFromSafe notSunset returns (uint32) {
        bytes memory payload = abi.encodeWithSignature(
            UPGRADE_TO_SIG,
            newUnderlying
        );

        uint32 propId = currentProposalCount;
        DataTypes.EmergencyRecoveryProposal memory prop = DataTypes
            .EmergencyRecoveryProposal({
                completesAt: uint64(block.timestamp) + timelockDuration,
                vetos: 0,
                status: DataTypes.Status.Queued,
                payload: payload
            });
        proposals[propId] = prop;
        currentProposalCount++;
        emit UpgradeProposed(propId, payload);
        return propId;
    }

    event UpgradeExecuted(
        uint32 proposalId,
        bool success,
        address governance,
        bytes payload
    );
    event UpgradeVetoed(uint32 proposalId);

    function completeGovernanceUpgrade(
        uint32 proposalId
    ) external onlyFromSafe notSunset {
        DataTypes.EmergencyRecoveryProposal storage prop = proposals[
            proposalId
        ];
        require(prop.completesAt > 0, "proposal does not exist");
        require(
            prop.completesAt < uint64(block.timestamp),
            "proposal is still timelocked"
        );
        require(
            prop.status == DataTypes.Status.Queued,
            "proposal must be queued"
        );

        uint256 tvp = votingAggregator.getTotalVotingPower();
        bool isVetoed = prop.vetos.divDown(tvp) > vetoThreshold;
        if (isVetoed) {
            prop.status = DataTypes.Status.Rejected;
            emit UpgradeVetoed(proposalId);
            return;
        }

        (bool success, ) = governance.call(prop.payload);
        require(success, "upgrade reverted");
        prop.status = DataTypes.Status.Executed;

        emit UpgradeExecuted(proposalId, success, governance, prop.payload);
    }

    event VetoCast(
        uint24 proposalId,
        uint256 castVetoPower,
        uint256 totalVetos
    );

    function veto(uint24 proposalId) external notSunset {
        DataTypes.EmergencyRecoveryProposal storage prop = proposals[
            proposalId
        ];
        require(prop.completesAt > 0, "proposal does not exist");
        require(
            prop.completesAt > uint64(block.timestamp),
            "proposal is out of timelock"
        );

        // Zero out the effect of previous vetos to avoid double-counting;
        uint256 currentVetoPower = vetos[proposalId][msg.sender];
        prop.vetos -= currentVetoPower;

        uint256 newVetoPower = votingAggregator.getVotingPower(msg.sender);
        prop.vetos += newVetoPower;
        vetos[proposalId][msg.sender] = newVetoPower;
        emit VetoCast(proposalId, newVetoPower, prop.vetos);
    }

    function setSunsetAt(uint64 _sunsetAt) external governanceOnly {
        sunsetAt = _sunsetAt;
    }
}
