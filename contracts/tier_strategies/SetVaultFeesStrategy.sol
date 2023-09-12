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
import "./BaseThresholdStrategy.sol";

contract SetVaultFeesStrategy is GovernanceOnly, BaseThresholdStrategy {
    uint256 public threshold;

    constructor(
        address _governance,
        uint256 _threshold,
        DataTypes.Tier memory underTier,
        DataTypes.Tier memory overTier
    ) BaseThresholdStrategy(underTier, overTier) GovernanceOnly(_governance) {
        threshold = _threshold;
    }

    function setParameters(
        uint256 _threshold,
        DataTypes.Tier calldata underTier,
        DataTypes.Tier calldata overTier
    ) external governanceOnly {
        threshold = _threshold;
        underThresholdTier = underTier;
        overThresholdTier = overTier;
    }

    function _isOverThreshold(
        bytes calldata _calldata
    ) internal view virtual override returns (bool) {
        // The function signature of the payload we're trying to decode is:
        // SetVaultFees(address vault, uint256 mintFee, uint256 redeemFee)
        (, uint256 mintFee, uint256 redeemFee) = abi.decode(
            _calldata[4:],
            (address, uint256, uint256)
        );
        return mintFee > threshold || redeemFee > threshold;
    }
}
