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

import "../../libraries/DataTypes.sol";
import "../../interfaces/ITierStrategy.sol";

abstract contract BaseThresholdStrategy is ITierStrategy {
    DataTypes.Tier public underThresholdTier;
    DataTypes.Tier public overThresholdTier;

    constructor(
        DataTypes.Tier memory _underThresholdTier,
        DataTypes.Tier memory _overThresholdTier
    ) {
        underThresholdTier = _underThresholdTier;
        overThresholdTier = _overThresholdTier;
    }

    function getTier(
        bytes calldata data
    ) external view returns (DataTypes.Tier memory) {
        if (_isOverThreshold(data)) {
            return overThresholdTier;
        } else {
            return underThresholdTier;
        }
    }

    function _isOverThreshold(
        bytes calldata data
    ) internal view virtual returns (bool);
}
