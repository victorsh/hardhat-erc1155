// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./Common.sol";
import "./IERC1155TokenReceiver.sol";

contract ERC1155MockReceiver is CommonConstants {
  bool public shouldReject;
  bytes public lastData;
  address public lastOperator;
  address public lastFrom;
  uint256 public lastId;
  uint256 public lastValue;

  function setShouldReject(bool _value) public {
    shouldReject = _value;
  }

  function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4) {
    lastOperator = _operator;
    lastFrom = _from;
    lastId = _id;
    lastValue = _value;
    lastData = _data;
    if (shouldReject == true) {
      revert("onERC155Received: transfer not accepted");
    } else {
      return ERC1155_ACCEPTED;
    }
  }

  function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external returns(bytes4) {
    lastOperator = _operator;
    lastFrom = _from;
    lastId = _ids[0];
    lastValue = _values[0];
    lastData = _data;
    if (shouldReject == true) {
      revert("onERC155Received: transfer not accepted");
    } else {
      return ERC1155_BATCH_ACCEPTED;
    }
  }
}