// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./access/ImmutableOwner.sol";
import "../libraries/DataTypes.sol";
import "../interfaces/ITierer.sol";

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract ActionTierConfig is ImmutableOwner, ITierer {
    mapping(bytes32 => ITierer) internal _tierStrategies;

    constructor(address _owner) ImmutableOwner(_owner) {}

    function _ruleKey(
        address _contract,
        bytes4 _sig
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_contract, _sig));
    }

    function setStrategy(
        address _contract,
        bytes4 _sig,
        address _strategy
    ) external onlyOwner {
      require(
        IERC165(_strategy).supportsInterface(type(ITierer).interfaceId),
        "_strategy must support ITierer interface"
      );

      _tierStrategies[_ruleKey(_contract, _sig)] = ITierer(_strategy);
    }

    function getStrategy(
      address _contract,
      bytes4 _sig
    ) external returns(address) {
      return address(_getStrategy(_contract, _sig));
    }

    function _getStrategy(
      address _contract,
      bytes4 _sig
    ) internal view returns (ITierer) {
      ITierer s = _tierStrategies[_ruleKey(_contract, _sig)];
      require(address(s) != address(0), "strategy not found");
      return s;
    }

    function getTier(
        address _contract,
        bytes calldata _calldata
    ) external view returns (DataTypes.Tier memory) {
      ITierer strategy = _getStrategy(_contract, _getSelector(_calldata));
      return strategy.getTier(_contract, _calldata);
    }

    function _getSelector(bytes memory _calldata) internal pure returns (bytes4 out) {
      assembly {
        out := and(
                mload(add(_calldata, 32)),
                0xFFFFFFFFF0000000000000000000000000000000000000000000000000000000
            )
      }
    }
}
