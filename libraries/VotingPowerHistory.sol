// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "./ScaledMath.sol";

library VotingPowerHistory {
    using VotingPowerHistory for History;
    using VotingPowerHistory for Record;
    using ScaledMath for uint256;

    struct Record {
        uint256 at;
        uint256 baseVotingPower;
        uint256 multiplier;
        int256 netDelegatedVotes;
    }

    function zeroRecord() internal pure returns (Record memory) {
        return
            Record({
                at: 0,
                baseVotingPower: 0,
                multiplier: ScaledMath.ONE,
                netDelegatedVotes: 0
            });
    }

    function total(Record memory record) internal pure returns (uint256) {
        return
            uint256(
                int256(record.baseVotingPower.mulDown(record.multiplier)) +
                    record.netDelegatedVotes
            );
    }

    struct History {
        mapping(address => Record[]) votes;
        mapping(address => mapping(address => uint256)) _delegations;
        mapping(address => uint256) _delegatedToOthers;
        mapping(address => uint256) _delegatedToSelf;
    }

    event VotesDelegated(address from, address to, uint256 amount);
    event VotesUndelegated(address from, address to, uint256 amount);

    function updateVotingPower(
        History storage history,
        address for_,
        uint256 baseVotingPower,
        uint256 multiplier,
        int256 netDelegatedVotes
    ) internal returns (Record memory) {
        Record[] storage votesFor = history.votes[for_];
        Record memory updatedRecord = Record({
            at: block.timestamp,
            baseVotingPower: baseVotingPower,
            multiplier: multiplier == 0 ? ScaledMath.ONE : multiplier,
            netDelegatedVotes: netDelegatedVotes
        });
        Record memory lastRecord = history.currentRecord(for_);
        if (lastRecord.at == block.timestamp && votesFor.length > 0) {
            votesFor[votesFor.length - 1] = updatedRecord;
        } else {
            history.votes[for_].push(updatedRecord);
        }
        return updatedRecord;
    }

    function getVotingPower(
        History storage history,
        address for_,
        uint256 at
    ) internal view returns (uint256) {
        (, Record memory record) = binarySearch(history.votes[for_], at);
        return record.total();
    }

    function currentRecord(
        History storage history,
        address for_
    ) internal view returns (Record memory) {
        Record[] memory records = history.votes[for_];
        if (records.length == 0) {
            return zeroRecord();
        } else {
            return records[records.length - 1];
        }
    }

    function binarySearch(
        Record[] memory records,
        uint256 at
    ) internal view returns (bool found, Record memory) {
        if (records.length == 0) {
            return (false, zeroRecord());
        } else if (records.length == 1) {
            Record memory rec = records[0];
            return rec.at <= at ? (true, rec) : (false, zeroRecord());
        } else {
            uint256 midIndex = records.length / 2;
            Record memory lowerBound = records[midIndex - 1];
            Record memory upperBound = records[midIndex];
            if (lowerBound.at <= at && at < upperBound.at) {
                return (true, lowerBound);
            } else if (upperBound.at <= at) {
                Record[] memory recs = subarrayOf(
                    records,
                    midIndex,
                    records.length
                );
                return binarySearch(recs, at);
            } else {
                Record[] memory recs = subarrayOf(records, 0, midIndex);
                return binarySearch(recs, at);
            }
        }
    }

    function subarrayOf(
        Record[] memory records,
        uint256 startIdx,
        uint256 endIdx
    ) internal pure returns (Record[] memory) {
        Record[] memory recs = new Record[](endIdx - startIdx);
        for (uint256 i = startIdx; i < endIdx; i++) {
            recs[i - startIdx] = records[i];
        }
        return recs;
    }

    function delegateVote(
        History storage history,
        address from,
        address to,
        uint256 amount
    ) internal {
        Record memory fromCurrent = history.currentRecord(from);

        uint256 availableToDelegate = fromCurrent.baseVotingPower.mulDown(
            fromCurrent.multiplier
        ) - history._delegatedToOthers[from];
        require(
            availableToDelegate >= amount,
            "insufficient balance to delegate"
        );

        history._delegatedToSelf[to] += amount;
        history._delegatedToOthers[from] += amount;
        history._delegations[from][to] += amount;

        history.updateVotingPower(
            from,
            fromCurrent.baseVotingPower,
            fromCurrent.multiplier,
            history.netDelegatedVotingPower(from)
        );
        Record memory toCurrent = history.currentRecord(to);
        history.updateVotingPower(
            to,
            toCurrent.baseVotingPower,
            toCurrent.multiplier,
            history.netDelegatedVotingPower(to)
        );
        emit VotesDelegated(from, to, amount);
    }

    function undelegateVote(
        History storage history,
        address from,
        address to,
        uint256 amount
    ) internal {
        require(
            history._delegations[from][to] >= amount,
            "user has not delegated enough to delegate"
        );

        history._delegatedToSelf[to] -= amount;
        history._delegatedToOthers[from] -= amount;
        history._delegations[from][to] -= amount;

        emit VotesUndelegated(from, to, amount);

        Record memory fromCurrent = history.currentRecord(from);
        history.updateVotingPower(
            from,
            fromCurrent.baseVotingPower,
            fromCurrent.multiplier,
            history.netDelegatedVotingPower(from)
        );
        Record memory toCurrent = history.currentRecord(to);
        history.updateVotingPower(
            to,
            toCurrent.baseVotingPower,
            toCurrent.multiplier,
            history.netDelegatedVotingPower(to)
        );
    }

    function netDelegatedVotingPower(
        History storage history,
        address who
    ) internal view returns (int256) {
        return
            int256(history._delegatedToSelf[who]) -
            int256(history._delegatedToOthers[who]);
    }

    function updateMultiplier(
        History storage history,
        address who,
        uint256 multiplier
    ) internal {
        Record memory current = history.currentRecord(who);
        require(current.multiplier <= multiplier, "cannot decrease multiplier");
        history.updateVotingPower(
            who,
            current.baseVotingPower,
            multiplier,
            current.netDelegatedVotes
        );
    }
}
