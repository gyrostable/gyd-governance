// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

library Delegations {
    struct Delegations {
        mapping(address => mapping(address => uint256)) _delegations;
        mapping(address => uint256) _delegatedToOthers;
        mapping(address => uint256) _delegatedToSelf;
    }

    event VotesDelegated(address from, address to, uint256 amount);
    event VotesUndelegated(address from, address to, uint256 amount);

    function delegateVote(
        Delegations storage delegations,
        address from,
        address to,
        uint256 amount,
        uint256 currentVotes
    ) internal {
        require(
            currentVotes - delegations._delegatedToOthers[from] >= amount,
            "insufficient balance to delegate"
        );

        delegations._delegatedToSelf[to] += amount;
        delegations._delegatedToOthers[from] += amount;
        delegations._delegations[from][to] += amount;

        emit VotesDelegated(from, to, amount);
    }

    function undelegateVote(
        Delegations storage delegations,
        address from,
        address to,
        uint256 amount
    ) internal {
        require(
            delegations._delegations[from][to] >= amount,
            "user has not delegated enough to delegate"
        );

        delegations._delegatedToSelf[to] -= amount;
        delegations._delegatedToOthers[from] -= amount;
        delegations._delegations[from][to] -= amount;

        emit VotesUndelegated(from, to, amount);
    }

    function netDelegatedVotes(
        Delegations storage delegations,
        address who
    ) internal view returns (int256) {
        return
            int256(delegations._delegatedToSelf[who]) -
            int256(delegations._delegatedToOthers[who]);
    }
}
