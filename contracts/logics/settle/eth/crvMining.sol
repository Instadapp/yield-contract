// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import { DSMath } from "../../../libs/safeMath.sol";

interface DSAInterface {
    function cast(address[] calldata _targets, bytes[] calldata _data, address _origin) external payable;
}

contract LogicOne {

    function getEthAddress() private pure returns(address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    function getCrvAddress() private pure returns(address) {
        return 0xD533a949740bb3306d119CC777fa900bA034cd52;
    }

    function getOriginAddress() private pure returns(address) {
        return 0xB7fA44c2E964B6EB24893f7082Ecc08c8d0c0F87; // Origin address
    }

    function getDsaAddress() private pure returns(address) {
        return address(0); // DSA address
    }

    function getGuageAddress() private pure returns(address) {
        return 0xAf615b36Db171fD5A369A0060b9bCB88fFf0190d; // DSA address
    }

    function getGuageName() private pure returns(string memory) {
        return "guage-3"; // Curve Guage name
    }

    function getCurveConnectAddress() private pure returns(address) {
        return 0x1568a9D336A7aC051DCC4bdcc4A0B09299DE5Daf;
    }

    function getCurveGuageConnectAddress() private pure returns(address) {
        return 0xAf615b36Db171fD5A369A0060b9bCB88fFf0190d;
    }

    function getUniswapConnectAddress() private pure returns(address) {
        return 0x62EbfF47B2Ba3e47796efaE7C51676762dC961c0;
    }

    function mineCrv(address token, uint amt, uint unitAmt) external {
        address[] memory _targets = new address[](2);
        bytes[] memory _data = new bytes[](2);
        _targets[1] = address(0); // Check9898 - address of curve 3pool connector
        _data[1] = abi.encodeWithSignature("deposit(address,uint256,uint256,uint256,uint256)", token, amt, unitAmt, uint(0), uint(0));
        _targets[2] = address(0); // Check9898 - address of curve 3pool guage connector
        _data[2] = abi.encodeWithSignature("deposit(string,uint256,uint256,uint256)", getGuageName(), uint(-1), uint(0), uint(0));
        DSAInterface(getDsaAddress()).cast(_targets, _data, getOriginAddress());
    }

    function redeemCrv(address token, uint amt, uint unitAmt) external {
        address[] memory _targets;
        bytes[] memory _data;
        if (amt == uint(-1)) {
            _targets = new address[](2);
            _data = new bytes[](2);
        } else {
            _targets = new address[](3);
            _data = new bytes[](3);
        }
        _targets[0] = address(0); // Check9898 - address of curve 3pool guage connector
        _data[0] = abi.encodeWithSignature("withdraw(string,uint256,uint256,uint256,uint256,uint256)", getGuageName(), uint(-1), uint(0), uint(0), uint(0), uint(0));
        _targets[1] = address(0); // Check9898 - address of curve 3pool connector
        _data[1] = abi.encodeWithSignature("withdraw(address,uint256,uint256,uint256,uint256)", token, amt, unitAmt, uint(0), uint(0));
        if (amt != uint(-1)) {
            _targets[2] = address(0); // Check9898 - address of curve 3pool guage connector
            _data[2] = abi.encodeWithSignature("deposit(string,uint256,uint256,uint256)", getGuageName(), uint(-1), uint(0), uint(0));
        }
        DSAInterface(getDsaAddress()).cast(_targets, _data, getOriginAddress());
    }

    function claimCrv() external {
        address[] memory _target = new address[](1);
        bytes[] memory _data = new bytes[](1);
        _target[0] = 0xAf615b36Db171fD5A369A0060b9bCB88fFf0190d; // Curve guage connector
        _data[0] = abi.encodeWithSignature("claimReward(string,uint256,uint256)", getGuageName(), 0, 0);
        DSAInterface(getDsaAddress()).cast(_target, _data, getOriginAddress());
    }

    function claimCrvAndSwap(uint amt, uint unitAmt) external {
        address crv = getCrvAddress();
        address eth = getEthAddress();
        address[] memory _target = new address[](1);
        bytes[] memory _data = new bytes[](1);
        _target[0] = getUniswapConnectAddress(); // Uniswap Connector
        _data[0] = abi.encodeWithSignature("sell(address,address,unit256,unit256,unit256,unit256)", eth, crv, amt, unitAmt, 0, 0);
        DSAInterface(getDsaAddress()).cast(_target, _data, getOriginAddress());
    }

    receive() external payable {}

}
