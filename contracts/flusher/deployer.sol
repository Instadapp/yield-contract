// SPDX-License-Identifier: MIT

pragma solidity ^0.6.8;

contract Controller {

  event LogNewMaster(address indexed master);
  event LogUpdateMaster(address indexed master);
  event LogEnableConnector(address indexed connector);
  event LogDisableImplementation(address indexed logic);
  event LogEnableImplementation(address indexed logic);
  event LogDisableConnector(address indexed connector);
  event LogAddSigner(address indexed signer);
  event LogRemoveSigner(address indexed signer);

  address private newMaster;
  address public master;
  mapping (address => bool) public connectors;
  mapping (address => bool) public implementations;
  mapping (address => bool) public signer;

  modifier isMaster() {
    require(msg.sender == master, "not-master");
    _;
  }

  // change the master address
  function changeMaster(address _newMaster) external isMaster {
    require(_newMaster != master, "already-a-master");
    require(_newMaster != address(0), "not-valid-address");
    require(newMaster != _newMaster, "already-a-new-master");
    newMaster = _newMaster;
    emit LogNewMaster(_newMaster);
  }

  // new master claiming master position
  function claimMaster() external {
    require(newMaster != address(0), "not-valid-address");
    require(msg.sender == newMaster, "not-new-master");
    master = newMaster;
    newMaster = address(0);
    emit LogUpdateMaster(master);
  }

  // enable connector
  function enableConnector(address _connector) external isMaster {
    require(!connectors[_connector], "already-enabled");
    require(_connector != address(0), "invalid-connector");
    connectors[_connector] = true;
    emit LogEnableConnector(_connector);
  }

  // disable connector
  function disableConnector(address _connector) external isMaster {
    require(connectors[_connector], "already-disabled");
    delete connectors[_connector];
    emit LogDisableConnector(_connector);
  }

  // enable implementation
  function enableImplementation(address _logic) external isMaster {
    require(!implementations[_logic], "already-enabled");
    require(_logic != address(0), "invalid-logic");
    implementations[_logic] = true;
    emit LogEnableImplementation(_logic);
  }

  // disable implementation
  function disableImplementation(address _logic) external isMaster {
    require(implementations[_logic], "already-disabled");
    delete implementations[_logic];
    emit LogDisableImplementation(_logic);
  }

  // enable signer
  function enableSigner(address _signer) external isMaster {
    require(_signer != address(0), "invalid-address");
    require(!signers[_signer], "signer-already-enabled");
    signers[_signer] = true;
    emit LogAddSigner(_signer);
  }

  // disable signer
  function disableSigner(address _signer) external isMaster {
    require(_signer != address(0), "invalid-address");
    require(signers[_signer], "signer-already-disabled");
    delete signers[_signer];
    emit LogRemoveSigner(_signer);
  }

  // check if connectors[] are enabled
  function isConnector(address[] calldata _connectors) external view returns (bool isOk) {
    isOk = true;
    for (uint i = 0; i < _connectors.length; i++) {
      if (!connectors[_connectors[i]]) {
        isOk = false;
        break;
      }
    }
  }

}

contract InstaDeployer is Controller {

  event LogNewFlusher(address indexed owner, address indexed flusher, address indexed logic);

  mapping (address => address) public flushers;

  // deploy create2 + minimal proxy
  function deployFlusher(address owner, address logic) public returns (address proxy) {
    require(!(isFlusherDeployed(getAddress(owner, logic))), "flusher-already-deployed");
    bytes32 salt = keccak256(abi.encodePacked(owner, logic));
    bytes20 targetBytes = bytes20(logic);
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      let clone := mload(0x40)
      mstore(
        clone,
        0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
      )
      mstore(add(clone, 0x14), targetBytes)
      mstore(
        add(clone, 0x28),
        0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
      )
      proxy := create2(0, clone, 0x37, salt)
    }
    flushers[proxy] = owner;
    emit LogNewFlusher(owner, proxy, logic);
  }

  // is flusher deployed?
  function isFlusherDeployed(address _address) public view returns (bool) {
    uint32 size;
    assembly {
      size := extcodesize(_address)
    }
    return (size > 0);
  }

  // compute create2 + minimal proxy address
  function getAddress(address owner, address logic) public view returns (address) {
    bytes32 codeHash = keccak256(getCreationCode(logic));
    bytes32 salt = keccak256(abi.encodePacked(owner, logic));
    bytes32 rawAddress = keccak256(
      abi.encodePacked(
        bytes1(0xff),
        address(this),
        salt,
        codeHash
      )
    );
    return address(bytes20(rawAddress << 96));
  }

  // get logic contract creation code
  function getCreationCode(address logic) public pure returns (bytes memory) {
    bytes20 a = bytes20(0x3D602d80600A3D3981F3363d3d373d3D3D363d73);
    bytes20 b = bytes20(logic);
    bytes15 c = bytes15(0x5af43d82803e903d91602b57fd5bf3);
    return abi.encodePacked(a, b, c);
  }

  constructor(address _master) public {
    master = _master;
    emit LogUpdateMaster(master);
  }

}