// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./SafeMath.sol";
import "./Address.sol";
import "./Strings.sol";
import "./Common.sol";
import "./IERC1155TokenReceiver.sol";
import "./IERC1155.sol";
import "hardhat/console.sol";

contract ERC1155 is CommonConstants {
  using SafeMath for uint256;
  using Address for address;

  /**
    @dev Either `TransferSingle` or `TransferBatch` MUST emit when tokens are transferred, including zero value transfers as well as minting or burning (see "Safe Transfer Rules" section of the standard).
    The `_operator` argument MUST be msg.sender.
    The `_from` argument MUST be the address of the holder whose balance is decreased.
    The `_to` argument MUST be the address of the recipient whose balance is increased.
    The `_id` argument MUST be the token type being transferred.
    The `_value` argument MUST be the number of tokens the holder balance is decreased by and match what the recipient balance is increased by.
    When minting/creating tokens, the `_from` argument MUST be set to `0x0` (i.e. zero address).
    When burning/destroying tokens, the `_to` argument MUST be set to `0x0` (i.e. zero address).
  */
  event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value);

  /**
    @dev Either `TransferSingle` or `TransferBatch` MUST emit when tokens are transferred, including zero value transfers as well as minting or burning (see "Safe Transfer Rules" section of the standard).
    The `_operator` argument MUST be msg.sender.
    The `_from` argument MUST be the address of the holder whose balance is decreased.
    The `_to` argument MUST be the address of the recipient whose balance is increased.
    The `_ids` argument MUST be the list of tokens being transferred.
    The `_values` argument MUST be the list of number of tokens (matching the list and order of tokens specified in _ids) the holder balance is decreased by and match what the recipient balance is increased by.
    When minting/creating tokens, the `_from` argument MUST be set to `0x0` (i.e. zero address).
    When burning/destroying tokens, the `_to` argument MUST be set to `0x0` (i.e. zero address).
  */
  event TransferBatch(address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values);

  /**
    @dev MUST emit when approval for a second party/operator address to manage all tokens for an owner address is enabled or disabled (absense of an event assumes disabled).
  */
  event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

  /**
    @dev MUST emit when the URI is updated for a token ID.
    URIs are defined in RFC 3986.
    The URI MUST point a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".
  */
  event URI(string _value, uint256 indexed _id);

  // id => (owner => balance)
  mapping (uint256 => mapping(address => uint256)) internal balances;
  // owner => (operator => approved)
  mapping (address => mapping(address => bool)) internal operatorApproval;

  /*
    bytes4(keccak256('supportsInterface(bytes4)'));
  */
  bytes4 constant private INTERFACE_SIGNATURE_ERC165 = 0x01ffc9a7;

  /*
    bytes4(keccak256("safeTransferFrom(address,address,uint256,uint256,bytes)")) ^
    bytes4(keccak256("safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)")) ^
    bytes4(keccak256("balanceOf(address,uint256)")) ^
    bytes4(keccak256("balanceOfBatch(address[],uint256[])")) ^
    bytes4(keccak256("setApprovalForAll(address,bool)")) ^
    bytes4(keccak256("isApprovedForAll(address,address)"));
  */
  bytes4 constant private INTERFACE_SIGNATURE_ERC1155 = 0xd9b67a26;

  function supportsInterface(bytes4 _interfaceId) public pure returns (bool) {
    if (_interfaceId == INTERFACE_SIGNATURE_ERC165 ||
        _interfaceId == INTERFACE_SIGNATURE_ERC1155) {
      return true;
    }

    return false;
  }
  
  function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external {
    require(_to != address(0x0), "_to must be non-zero");
    require(_from == msg.sender || operatorApproval[_from][msg.sender] == true, "Need operator approval for 3rd party transfers.");

    balances[_id][_from] = balances[_id][_from].sub(_value);
    balances[_id][_to] = balances[_id][_from].add(_value);

    emit TransferSingle(msg.sender, _from, _to, _id, _value);

    if (_to.isContract()) {
      _doSafeTransferAcceptanceCheck(msg.sender, _from, _to, _id, _value, _data);
    }
  }

  function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external {
    require(_to != address(0x0), "destination address must be non-zero");
    require(_ids.length == _values.length, "_ids and _values array length must match");
    require(_from == msg.sender || operatorApproval[_from][msg.sender] == true, "Need operator approval for 3rd party transfers.");

    for (uint256 i = 0; i < _ids.length; ++i) {
      uint256 id = _ids[i];
      uint256 value = _values[i];
      balances[id][_from] = balances[id][_from].sub(value);
      balances[id][_to] = balances[id][_to].add(value);
    }

    emit TransferBatch(msg.sender, _from, _to, _ids, _values);
    if(_to.isContract()) {
      _doSafeBatchTransferAcceptanceCheck(msg.sender, _from, _to, _ids, _values, _data);
    }
  }

  function balanceOf(address _owner, uint256 _id) external view returns (uint256) {
    return balances[_id][_owner];
  }

  function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view returns (uint256[] memory) {
    require(_owners.length == _ids.length);
    uint256[] memory balances_ = new uint256[](_owners.length);

    for (uint256 i = 0; i < _owners.length; ++i) {
      balances_[i] = balances[_ids[i]][_owners[i]];
    }

    return balances_;
  }

  function setApprovalForAll(address _operator, bool _approved) external {
    operatorApproval[msg.sender][_operator] = _approved;
    emit ApprovalForAll(msg.sender, _operator, _approved);
  }

  function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
    return operatorApproval[_owner][_operator];
  }

  function _doSafeTransferAcceptanceCheck(address _operator, address _from, address _to, uint256 _id, uint256 _value, bytes memory _data) internal {
    // If this was a hybrid standards solution you would have to check ERC165(_to).supportsInterface(0x4e2312e0) here but as this is a pure implementation of an ERC-1155 token set as recommended by
    // the standard, it is not necessary. The below should revert in all failure cases i.e. _to isn't a receiver, or it is and either returns an unknown value or it reverts in the call to indicate non-acceptance.

    // Note: if the below reverts in the onERC1155Received function of the _to address you will have an undefined revert reason returned rather than the one in the require test.
    // If you want predictable revert reasons consider using low level _to.call() style instead so the revert does not bubble up and you can revert yourself on the ERC1155_ACCEPTED test.
    require(ERC1155TokenReceiver(_to).onERC1155Received(_operator, _from, _id, _value, _data) == ERC1155_ACCEPTED, "contract returned an unknown value from onERC1155Received");
  }

  function _doSafeBatchTransferAcceptanceCheck(address _operator, address _from, address _to, uint256[] memory _ids, uint256[] memory _values, bytes memory _data) internal {
    // If this was a hybrid standards solution you would have to check ERC165(_to).supportsInterface(0x4e2312e0) here but as this is a pure implementation of an ERC-1155 token set as recommended by
    // the standard, it is not necessary. The below should revert in all failure cases i.e. _to isn't a receiver, or it is and either returns an unknown value or it reverts in the call to indicate non-acceptance.

    // Note: if the below reverts in the onERC1155BatchReceived function of the _to address you will have an undefined revert reason returned rather than the one in the require test.
    // If you want predictable revert reasons consider using low level _to.call() style instead so the revert does not bubble up and you can revert yourself on the ERC1155_BATCH_ACCEPTED test.
    require(ERC1155TokenReceiver(_to).onERC1155BatchReceived(_operator, _from, _ids, _values, _data) == ERC1155_BATCH_ACCEPTED, "contract returned an unknown value from onERC1155BatchReceived");
  }
}