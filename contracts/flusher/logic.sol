// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

interface DeployerInterface {
  function signer(address) external view returns (bool); 
  function master() external view returns (address); 
  function isConnector(address[] calldata) external view returns (bool);
  function implementationLogic(address) external view returns (bool);
}

contract Setup {

    function deployer() public pure returns (DeployerInterface) {
        return DeployerInterface(address(0)); // TODO - change.
    }

    string constant public name = "Flusher-v1";

    function spell(address _target, bytes memory _data) internal {
        require(_target != address(0), "target-invalid");
        assembly {
        let succeeded := delegatecall(gas(), _target, add(_data, 0x20), mload(_data), 0, 0)
        switch iszero(succeeded)
            case 1 {
                let size := returndatasize()
                returndatacopy(0x00, 0x00, size)
                revert(0x00, size)
            }
        }
    }

}

contract UpgradeableProxy is Setup {
    event Upgraded(address indexed implementation);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function changeImplementation(address newImplementation) public {
        require(deployer().master() == msg.sender, "not-master");
        require(deployer().implementationLogic(newImplementation), "not-whitelisted-logic");
        // require(Address.isContract(newImplementation), "UpgradeableProxy: new implementation is not a contract");

        bytes32 slot = _IMPLEMENTATION_SLOT;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, newImplementation)
        }
        emit Upgraded(newImplementation);
    }
}


contract Flusher is UpgradeableProxy {
  event LogCast(address indexed sender, uint value);

  function cast(address[] calldata _targets, bytes[] calldata _datas) external payable {
    require(deployer().signer(msg.sender), "not-signer");
    require(_targets.length == _datas.length , "invalid-array-length");
    require(deployer().isConnector(_targets), "not-connector");
    for (uint i = 0; i < _targets.length; i++) {
        spell(_targets[i], _datas[i]);
    }
    emit LogCast(msg.sender, msg.value);
  }

  receive() external payable {}
}