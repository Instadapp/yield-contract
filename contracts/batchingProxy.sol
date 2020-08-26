// SPDX-License-Identifier: MIT

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

interface IndexInterface {
  function master() external view returns (address);
}

contract Registry {

  event LogAddSigner(address indexed signer);
  event LogRemoveSigner(address indexed signer);
  
  event LogSuccess(address indexed flusher, bytes callData);
  event LogFailed(address indexed flusher, bytes callData);


  IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723);

  mapping (address => bool) public signer;

  modifier isMaster() {
    require(msg.sender == instaIndex.master(), "not-master");
    _;
  }

  modifier isSigner() {
    require(signer[msg.sender], "not-chief");
    _;
  }

  /**
    * @dev Enable New Signer.
    * @param _signer Address of the new signer.
  */
  function enableSigner(address _signer) external isMaster {
      require(_signer != address(0), "invalid-address");
      require(!signer[_signer], "signer-already-enabled");
      signer[_signer] = true;
      emit LogAddSigner(_signer);
  }

  /**
    * @dev Disable Signer.
    * @param _signer Address of the existing signer.
  */
  function disableSigner(address _signer) external isMaster {
      require(_signer != address(0), "invalid-address");
      require(signer[_signer], "signer-already-disabled");
      delete signer[_signer];
      emit LogRemoveSigner(_signer);
  }

  function batchTx(address[] memory flushers, bytes[] memory calldatas) external isSigner {
    require(flushers.length == calldatas.length, "not-same-length");
    for (uint i = 0; i < flushers.length; i++) {
        (bool status, ) = payable(flushers[i]).call(calldatas[i]);
        if (status) emit LogSuccess(flushers[i], calldatas[i]);
        else emit LogFailed(flushers[i], calldatas[i]);
    }
  }
}
