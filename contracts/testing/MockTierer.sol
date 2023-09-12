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

import "../../interfaces/ITierer.sol";
import "../../libraries/DataTypes.sol";

contract MockTierer is ITierer {
    DataTypes.Tier private tier;
    OverrideTier[] private overrides;

    struct OverrideTier {
        address addr;
        DataTypes.Tier tier;
    }

    constructor(DataTypes.Tier memory _tier) {
        tier = _tier;
    }

    function setOverride(address _addr, DataTypes.Tier memory _tier) public {
        overrides.push(OverrideTier({addr: _addr, tier: _tier}));
    }

    function getTier(
        address _addr,
        bytes calldata
    ) external view returns (DataTypes.Tier memory) {
        for (uint256 i = 0; i < overrides.length; i++) {
            if (overrides[i].addr == _addr) {
                return overrides[i].tier;
            }
        }

        return tier;
    }
}
