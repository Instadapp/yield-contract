// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import { DSMath } from "../../../libs/safeMath.sol";

interface DSAInterface {
    function cast(address[] calldata _targets, bytes[] calldata _data, address _origin) external payable;
}

contract LogicOne {

    function getUsdcAddress() private pure returns(address) {
        return 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    }

    function getCrvAddress() private pure returns(address) {
        return 0xD533a949740bb3306d119CC777fa900bA034cd52;
    }

    function getOriginAddress() private pure returns(address) {
        return 0xB7fA44c2E964B6EB24893f7082Ecc08c8d0c0F87;
    }

    function getDsaAddress() private pure returns(address) {
        return address(0); // DSA address
    }

    function getGuageAddress() private pure returns(address) {
        return 0xAf615b36Db171fD5A369A0060b9bCB88fFf0190d;
    }

    function getGuageName() private pure returns(string memory) {
        return "guage-3";
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
        _targets[1] = getCurveConnectAddress();
        _data[1] = abi.encodeWithSignature("deposit(address,uint256,uint256,uint256,uint256)", token, amt, unitAmt, uint(0), uint(0));
        _targets[2] = getCurveGuageConnectAddress();
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
        _targets[0] = getCurveGuageConnectAddress();
        _data[0] = abi.encodeWithSignature("withdraw(string,uint256,uint256,uint256,uint256,uint256)", getGuageName(), uint(-1), uint(0), uint(0), uint(0), uint(0));
        _targets[1] = getCurveConnectAddress();
        _data[1] = abi.encodeWithSignature("withdraw(address,uint256,uint256,uint256,uint256)", token, amt, unitAmt, uint(0), uint(0));
        if (amt != uint(-1)) {
            _targets[2] = getCurveGuageConnectAddress();
            _data[2] = abi.encodeWithSignature("deposit(string,uint256,uint256,uint256)", getGuageName(), uint(-1), uint(0), uint(0));
        }
        DSAInterface(getDsaAddress()).cast(_targets, _data, getOriginAddress());
    }

    function claimCrv() external {
        address[] memory _target = new address[](1);
        bytes[] memory _data = new bytes[](1);
        _target[0] = getCurveGuageConnectAddress();
        _data[0] = abi.encodeWithSignature("claimReward(string,uint256,uint256)", getGuageName(), 0, 0);
        DSAInterface(getDsaAddress()).cast(_target, _data, getOriginAddress());
    }

    function claimCrvAndSwap(uint amt, uint unitAmt) external {
        address[] memory _target = new address[](1);
        bytes[] memory _data = new bytes[](1);
        _target[0] = getUniswapConnectAddress(); // CHECK9898 - Use Uniswap multi path for Good Swap
        _data[0] = abi.encodeWithSignature("sell(address,address,unit256,unit256,unit256,unit256)", getUsdcAddress(), getCrvAddress(), amt, unitAmt, 0, 0);
        DSAInterface(getDsaAddress()).cast(_target, _data, getOriginAddress());
    }
}
