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

interface ILockingVault {
    function deposit(uint256 _amount) external;

    function deposit(uint256 _amount, address _delegate) external;

    event Deposit(
        address indexed from,
        address indexed delegate,
        uint256 amount
    );

    function initiateWithdrawal(
        uint256 _amount,
        address _delegate
    ) external returns (uint256);

    function withdraw(uint256 withdrawalId) external;

    event WithdrawalQueued(
        uint256 indexed id,
        address indexed to,
        address indexed delegate,
        uint256 withdrawalAt,
        uint256 amount
    );
    event WithdrawalCompleted(
        uint256 indexed id,
        address indexed to,
        uint256 amount
    );
}
