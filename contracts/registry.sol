// SPDX-License-Identifier: MIT

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

interface IndexInterface {
  function master() external view returns (address);
}

contract Registry {

  event LogAddChief(address indexed chief);
  event LogRemoveChief(address indexed chief);
  event LogAddSigner(address indexed signer);
  event LogRemoveSigner(address indexed signer);
  event LogSwitchPool(address pool, bool);
  event LogUpdatePoolCap(address pool, uint newCap);
  event LogUpdatePoolLogic(address pool, address newLogic);
  event LogUpdateInsureFee(address pool, uint newFee);

  IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723);

  mapping (address => bool) public chief;
  mapping (address => bool) public signer;
  mapping (address => bool) public isPool;
  mapping (address => address) public poolLogic;
  mapping (address => uint) public poolCap;
  mapping (address => uint) public insureFee;

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
    * @dev Enable New Signer.
    * @param _signer Address of the new signer.
  */
  function enableSigner(address _signer) external isChief {
      require(_signer != address(0), "address-not-valid");
      require(!signer[_signer], "signer-already-enabled");
      signer[_signer] = true;
      emit LogAddSigner(_signer);
  }

  /**
    * @dev Disable Signer.
    * @param _signer Address of the existing signer.
  */
  function disableSigner(address _signer) external isChief {
      require(_signer != address(0), "address-not-valid");
      require(signer[_signer], "signer-already-disabled");
      delete signer[_signer];
      emit LogRemoveSigner(_signer);
  }

  function switchPool(address _pool) external isMaster {
    isPool[_pool] = !isPool[_pool];
    emit LogSwitchPool(_pool, isPool[_pool]);
  }

  function updatePoolCap(address _pool, uint _newCap) external isChief {
    require(isPool[_pool], "not-a-pool");
    poolCap[_pool] = _newCap;
    emit LogUpdatePoolCap(_pool, _newCap);
  }

  function updatePoolLogic(address _pool, address _newLogic) external isChief {
    require(isPool[_pool], "not-a-pool");
    require(_newLogic != address(0), "address-0");
    poolLogic[_pool] = _newLogic;
    emit LogUpdatePoolLogic(_pool, _newLogic);
  }

  function updateInsureFee(address _pool, uint _newFee) external isChief {
    require(isPool[_pool], "not-a-pool");
    require(_newFee < 1000000000000000000, "insure-fee-limit-reached");
    insureFee[_pool] = _newFee;
    emit LogUpdateInsureFee(_pool, _newFee);
  }

  constructor(address _chief) public {
    chief[_chief] = true;
    emit LogAddChief(_chief);
  } 
}
