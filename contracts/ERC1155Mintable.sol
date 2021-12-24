// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./ERC1155.sol";

contract ERC1155Mintable is ERC1155 {
  using SafeMath for uint256;
  using Address for address;

  // id => creators
  mapping (uint256 => address) public creators;
  // nonce to ensure unique id on each mint
  uint256 public nonce;

  modifier creatorOnly(uint256 _id) {
    require(creators[_id] == msg.sender);
    _;
  }

  function create(uint256 _initialSupply, string calldata _uri) external returns(uint256 _id) {
    _id = ++nonce;
    creators[_id] = msg.sender;
    balances[_id][msg.sender] = _initialSupply;
    emit TransferSingle(msg.sender, address(0x0), msg.sender, _id, _initialSupply);
    if (bytes(_uri).length > 0)
      emit URI(_uri, _id);
  }

  function mint(uint256 _id, address[] calldata _to, uint256[] calldata _quantities) external creatorOnly(_id) {
    for (uint256 i = 0; i < _to.length; ++i) {
      address to = _to[i];
      uint256 quantity = _quantities[i];

      balances[_id][to] = quantity.add(balances[_id][to]);
      emit TransferSingle(msg.sender, address(0x0), to, _id, quantity);

      if (to.isContract()) {
        _doSafeTransferAcceptanceCheck(msg.sender, msg.sender, to, _id, quantity, '');
      }
    }
  }

  function setURI(string calldata _uri, uint256 _id) external creatorOnly(_id) {
    emit URI(_uri, _id);
  }
}