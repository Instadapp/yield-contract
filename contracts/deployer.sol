// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

contract Deployer {

  mapping (address => bool) public flushers;

  event LogNewFlusher(address indexed owner, address indexed flusher, address indexed logic);

  // deploy create2 + minimal proxy
  function deployLogic(address owner, address logic) public returns (address proxy) {
    require(!(isFlusherDeployed(getAddress(owner, logic))), "flusher-already-deployed");
    bytes32 salt = keccak256(abi.encodePacked(owner));
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
    flushers[proxy] = true;
    emit LogNewFlusher(owner, proxy, logic);
  }

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
    bytes32 salt = keccak256(abi.encodePacked(owner));
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

  function getCreationCode(address logic) public pure returns (bytes memory) {
    bytes20 a = bytes20(0x3D602d80600A3D3981F3363d3d373d3D3D363d73);
    bytes20 b = bytes20(logic);
    bytes15 c = bytes15(0x5af43d82803e903d91602b57fd5bf3);
    return abi.encodePacked(a, b, c);
  }
}