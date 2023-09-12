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

import "./NFTVault.sol";
import "../../libraries/VotingPowerHistory.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/IVotingPowersUpdater.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract CouncillorNFTVault is NFTVault, IVotingPowersUpdater {
    using VotingPowerHistory for VotingPowerHistory.History;
    using VotingPowerHistory for VotingPowerHistory.Record;

    string internal constant _VAULT_TYPE = "CouncillorNFT";

    address internal immutable underlyingAddress;

    constructor(address _owner, address _underlyingAddress) NFTVault(_owner) {
        underlyingAddress = _underlyingAddress;
        sumVotingPowers = IERC721Enumerable(_underlyingAddress).totalSupply();
    }

    modifier onlyUnderlying() {
        require(msg.sender == address(underlyingAddress));
        _;
    }

    function updateBaseVotingPower(
        address _user,
        address _delegate,
        uint128 _addedCount
    ) external onlyUnderlying {
        VotingPowerHistory.Record memory ovp = history.currentRecord(_user);

        uint256 oldTotal = ovp.total();
        VotingPowerHistory.Record memory nvp = history.updateVotingPower(
            _user,
            ovp.baseVotingPower + _addedCount,
            ovp.multiplier,
            ovp.netDelegatedVotes
        );
        sumVotingPowers += (nvp.total() - oldTotal);
        if (_delegate != address(0) && _delegate != _user) {
            _delegateVote(_user, _delegate, _addedCount);
        }
    }

    function getVaultType() external pure returns (string memory) {
        return _VAULT_TYPE;
    }
}
