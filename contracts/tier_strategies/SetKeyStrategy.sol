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

import "../access/GovernanceOnly.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/ITierStrategy.sol";

contract SetKeyStrategy is ITierStrategy, GovernanceOnly {
    mapping(bytes32 => MapValue) keysToTiers;
    DataTypes.Tier public defaultTier;

    struct MapValue {
        DataTypes.Tier tier;
        bool present;
    }

    constructor(
        address _governance,
        DataTypes.Tier memory _defaultTier
    ) GovernanceOnly(_governance) {
        defaultTier = _defaultTier;
    }

    function setDefaultTier(
        DataTypes.Tier memory _defaultTier
    ) external governanceOnly {
        defaultTier = _defaultTier;
    }

    function setValue(
        bytes32 key,
        DataTypes.Tier memory tier
    ) external governanceOnly {
        keysToTiers[key] = MapValue({present: true, tier: tier});
    }

    function getTier(
        bytes calldata _calldata
    ) external view returns (DataTypes.Tier memory) {
        bytes32 key = abi.decode(_calldata[4:36], (bytes32));

        MapValue memory mapValue = keysToTiers[key];
        if (!mapValue.present) {
            return defaultTier;
        }

        return mapValue.tier;
    }
}
