// SPDX-License-Identifier: MIT

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

interface IndexInterface {
  function master() external view returns (address);
}

contract Registry {

  event LogAddChief(address indexed chief);
  event LogRemoveChief(address indexed chief);
  event LogUpdatePoolLogic(address token, address newLogic);
  event LogUpdateFee(address token, uint newFee);
  event LogUpdateCap(address token, uint newFee);
  event LogAddSettleLogic(address indexed token, address indexed logic);
  event LogRemoveSettleLogic(address indexed token, address indexed logic);

  IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723);

  mapping (address => bool) public chief;
  mapping (address => address) public poolLogic;
  mapping (address => uint) public poolCap;
  mapping (address => uint) public fee;
  mapping (address => mapping(address => bool)) public settleLogic;

  modifier isMaster() {
    require(msg.sender == instaIndex.master(), "not-master");
    _;
  }

  modifier isChief() {
    require(chief[msg.sender] || msg.sender == instaIndex.master(), "not-chief");
    _;
  }

  /**
    * @dev Enable New Chief.
    * @param _chief Address of the new chief.
  */
  function enableChief(address _chief) external isMaster {
    require(_chief != address(0), "address-not-valid");
    require(!chief[_chief], "chief-already-enabled");
    chief[_chief] = true;
    emit LogAddChief(_chief);
  }

  /**
    * @dev Disable Chief.
    * @param _chief Address of the existing chief.
  */
  function disableChief(address _chief) external isMaster {
    require(_chief != address(0), "address-not-valid");
    require(chief[_chief], "chief-already-disabled");
    delete chief[_chief];
    emit LogRemoveChief(_chief);
  }

  /**
    * @dev update pool rate logic
    * @param _pool pool address
    * @param _newLogic new rate logic address
  */
  function updatePoolLogic(address _pool, address _newLogic) external isMaster {
    require(_pool != address(0), "invalid-pool");
    require(_newLogic != address(0), "invalid-address");
    require(poolLogic[_pool] != _newLogic, "same-pool-logic");
    poolLogic[_pool] = _newLogic;
    emit LogUpdatePoolLogic(_pool, _newLogic);
  }

  /**
    * @dev update pool fee
    * @param _pool pool address
    * @param _newFee new fee amount
  */
  function updateFee(address _pool, uint _newFee) external isMaster {
    require(_pool != address(0), "invalid-pool");
    require(_newFee < 3 * 10 ** 17, "insure-fee-limit-reached");
    require(fee[_pool] != _newFee, "same-pool-fee");
    fee[_pool] = _newFee;
    emit LogUpdateFee(_pool, _newFee);
  }

  /**
    * @dev update pool fee
    * @param _pool pool address
    * @param _newCap new fee amount
  */
  function updateCap(address _pool, uint _newCap) external isMaster {
    require(_pool != address(0), "invalid-pool");
    poolCap[_pool] = _newCap;
    emit LogUpdateCap(_pool, _newCap);
  }

  /**
    * @dev adding settlement logic
    * @param _pool pool address
    * @param _logic logic proxy
  */
  function addSettleLogic(address _pool, address _logic) external isMaster {
    require(_pool != address(0), "invalid-pool");
    settleLogic[_pool][_logic] = true;
    emit LogAddSettleLogic(_pool, _logic);
  }

  /**
    * @dev removing settlement logic
    * @param _pool pool address
    * @param _logic logic proxy
  */
  function removeSettleLogic(address _pool, address _logic) external isMaster {
    require(_pool != address(0), "invalid-pool");
    delete settleLogic[_pool][_logic];
    emit LogRemoveSettleLogic(_pool, _logic);
  }

  /**
    * @dev check if settle logics are enabled
    * @param _pool token pool address
    * @param _logics array of logic proxy
  */
  function checkSettleLogics(address _pool, address[] calldata _logics) external view returns(bool isOk) {
    isOk = true;
    for (uint i = 0; i < _logics.length; i++) {
      if (!settleLogic[_pool][_logics[i]]) {
        isOk = false;
        break;
      }
    }
  }

  constructor(address _chief) public {
    chief[_chief] = true;
    emit LogAddChief(_chief);
  }
}
