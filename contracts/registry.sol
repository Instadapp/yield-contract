// SPDX-License-Identifier: MIT

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

interface IndexInterface {
  function master() external view returns (address);
  function build(address _owner, uint accountVersion, address _origin) external returns (address _account);
}

contract Registry {

  event LogAddChief(address indexed chief);
  event LogRemoveChief(address indexed chief);
  event LogAddSigner(address indexed signer);
  event LogRemoveSigner(address indexed signer);
  event LogUpdatePool(address pool, bool poolState);
  event LogUpdatePoolLogic(address pool, address newLogic);
  event LogUpdateTariff(address pool, uint newTariff);
  event LogAddPool(address indexed token, address indexed pool);
  event LogRemovePool(address indexed token, address indexed pool);
  event LogNewDSA(address indexed pool, address indexed dsa);
  event LogRemoveDSA(address indexed pool, address indexed dsa);
  event LogAddSettleLogic(address indexed pool, address indexed logic);
  event LogRemoveSettleLogic(address indexed pool, address indexed logic);

  IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723);

  mapping (address => bool) public chief;
  mapping (address => bool) public signer;
  mapping (address => bool) public isPool;
  mapping (address => address) public poolToken;
  mapping (address => address) public poolLogic;
  mapping (address => uint) public poolCap;
  mapping (address => uint) public tariff;
  mapping (address => mapping(address => bool)) public settleLogic;
  mapping (address => mapping(address => bool)) public isDsa; // pool => dsa => bool
  mapping (address => address[]) public dsaArr; // pool => all dsa in array

  modifier isMaster() {
    require(msg.sender == instaIndex.master(), "not-master");
    _;
  }

  modifier isChief() {
    require(chief[msg.sender] || msg.sender == instaIndex.master(), "not-chief");
    _;
  }

  function getDsaLength(address _pool) external view returns(uint) {
    return dsaArr[_pool].length;
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
    * @dev Enable New Signer.
    * @param _signer Address of the new signer.
  */
  function enableSigner(address _signer) external isChief {
      require(_signer != address(0), "invalid-address");
      require(!signer[_signer], "signer-already-enabled");
      signer[_signer] = true;
      emit LogAddSigner(_signer);
  }

  /**
    * @dev Disable Signer.
    * @param _signer Address of the existing signer.
  */
  function disableSigner(address _signer) external isChief {
      require(_signer != address(0), "invalid-address");
      require(signer[_signer], "signer-already-disabled");
      delete signer[_signer];
      emit LogRemoveSigner(_signer);
  }

  /**
    * @dev Add New Pool
    * @param token ERC20 token address
    * @param pool pool address
  */
  function addPool(address token, address pool) external isMaster {
    require(token != address(0) && pool != address(0), "invalid-address");
    require(poolToken[token] == address(0), "pool-already-added");
    poolToken[token] = pool;
    emit LogAddPool(token, pool);
  }

  /**
    * @dev Remove Pool
    * @param token ERC20 token address
  */
  function removePool(address token) external isMaster {
    require(token != address(0), "invalid-address");
    require(poolToken[token] != address(0), "pool-already-removed");
    address poolAddr = poolToken[token];
    delete poolToken[token];
    emit LogRemovePool(token, poolAddr);
  }

  /**
    * @dev enable / disable pool
    * @param _pool pool address
  */
  function updatePool(address _pool) external isMaster {
    isPool[_pool] = !isPool[_pool];
    emit LogUpdatePool(_pool, isPool[_pool]);
  }

  /**
    * @dev update pool rate logic
    * @param _pool pool address
    * @param _newLogic new rate logic address
  */
  function updatePoolLogic(address _pool, address _newLogic) external isMaster {
    require(isPool[_pool], "not-pool");
    require(_newLogic != address(0), "invalid-address");
    require( poolLogic[_pool] != _newLogic, "same-pool-logic");
    poolLogic[_pool] = _newLogic;
    emit LogUpdatePoolLogic(_pool, _newLogic);
  }

  /**
    * @dev update pool tariff
    * @param _pool pool address
    * @param _newTariff new tariff amount
  */
  function updateTariff(address _pool, uint _newTariff) external isMaster {
    require(isPool[_pool], "not-pool");
    require(_newTariff < 3 * 10 ** 17, "insure-tariff-limit-reached");
    require(tariff[_pool] != _newTariff, "same-pool-tariff");
    tariff[_pool] = _newTariff;
    emit LogUpdateTariff(_pool, _newTariff);
  }

  function addSettleLogic(address _pool, address _logic) external isMaster {
    require(isPool[_pool], "not-pool");
    settleLogic[_pool][_logic] = true;
    emit LogAddSettleLogic(_pool, _logic);
  }

  function removeSettleLogic(address _pool, address _logic) external isMaster {
    require(isPool[_pool], "not-pool");
    delete settleLogic[_pool][_logic];
    emit LogRemoveSettleLogic(_pool, _logic);
  }

  function checkSettleLogics(address _pool, address[] calldata _logics) external view returns(bool) {
    for (uint i = 0; i < _logics.length; i++) {
      if (!settleLogic[_pool][_logics[i]]) {
        return false;
      }
    }
    return true;
  }

  /**
    * @dev add dsa for a pool 
    * @param _pool pool address
    * @param _dsa DSA address
  */
  function addDsa(address _pool, address _dsa) external isMaster {
    require(isPool[_pool], "not-pool");
    if (_dsa == address(0)) _dsa = instaIndex.build(_pool, 1, address(this));
    isDsa[_pool][_dsa] = true;
    dsaArr[_pool].push(_dsa);
    emit LogNewDSA(_pool, _dsa);
  }

  /**
    * @dev remove dsa from a pool 
    * @param _pool pool address
    * @param _dsa DSA address
  */
  function removeDsa(address _pool, address _dsa) external isMaster {
    require(isPool[_pool], "not-pool");
    require(isDsa[_pool][_dsa], "not-dsa-for-pool");
    delete isDsa[_pool][_dsa];
    emit LogRemoveDSA(_pool, _dsa);
  }

  constructor(address _chief) public {
    chief[_chief] = true;
    emit LogAddChief(_chief);
  } 
}
