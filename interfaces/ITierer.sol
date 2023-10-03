// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "../libraries/DataTypes.sol";

interface ITierer {
    function getTier(
        address _contract,
        bytes calldata payload
    ) external view returns (DataTypes.Tier memory);
}
