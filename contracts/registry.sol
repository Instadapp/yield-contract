// SPDX-License-Identifier: MIT

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

// TODO
// function for adding and removing rate logics.
// Added fee variable and required function to change it.
// Link all the contract more properly.
// Have to think more on pricePerToken function.

interface IndexInterface {
  function master() external view returns (address);
}

contract Registry {

  event LogAddChief(address indexed chief);
  event LogRemoveChief(address indexed chief);

  IndexInterface public instaIndex;

  mapping (address => bool) public chief;
  mapping (address => address) public dsa;
  mapping (address => address) public logic;

  modifier isMaster() {
    require(msg.sender == instaIndex.master(), "not-master");
    _;
  }

  modifier isController() {
    require(chief[msg.sender] || msg.sender == instaIndex.master(), "not-chief");
    _;
  }

  constructor(address _index) public {
    instaIndex = IndexInterface(_index);
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
}
