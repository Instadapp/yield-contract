// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import { DSMath } from "../../../libs/safeMath.sol";

interface CTokenInterface {
    function borrowBalanceCurrent(address account) external returns (uint256);
    function exchangeRateCurrent() external returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function underlying() external view returns (address);
}

interface DSAInterface {
    function cast(address[] calldata _targets, bytes[] calldata _datas, address _origin) external payable;
}

interface CompTroller {
    function getAllMarkets() external view returns (address[] memory);
}

interface OracleComp {
    function getUnderlyingPrice(address) external view returns (uint);
}

interface InstaMapping {
    function cTokenMapping(address) external view returns (address);
}

contract LogicOne is DSMath {

    struct CastData {
        address[] dsaTargets;
        bytes[] dsaData;
    }

    function getOriginAddress() private pure returns(address) {
        return 0xB7fA44c2E964B6EB24893f7082Ecc08c8d0c0F87; // DSA address
    }

    function getEthAddress() private pure returns(address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // DSA address
    }

    function getCompAddress() private pure returns(address) {
        return 0xc00e94Cb662C3520282E6f5717214004A7f26888; // DSA address
    }

    function getComptrollerAddress() private pure returns (address) {
        return 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    function getDaiAddress() private pure returns(address) {
        return 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI address
    }

    function getCdaiAddress() private pure returns(address) {
        return 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643; // CDAI address
    }

    function getDsaAddress() private pure returns(address) {
        return address(0); // DSA address
    }

    function getCompoundConnectAddress() private pure returns(address) {
        return 0x07F81230d73a78f63F0c2A3403AD281b067d28F8;
    }

    function getFlashloanConnectAddress() private pure returns(address) {
        return 0xaA3EA0b22802d68DA73D5f4D3f9F1C7C238fE03A;
    }

    function getCompConnectAddress() private pure returns(address) {
        return 0xB4a04F1C194bEed64FCE27843B5b3079339cdaD4;
    }

    function getUniswapConnectAddress() private pure returns(address) {
        return 0x62EbfF47B2Ba3e47796efaE7C51676762dC961c0;
    }
    
    function checkCompoundAssets() private {
        address[] memory allMarkets = CompTroller(getComptrollerAddress()).getAllMarkets();
        uint supply;
        uint borrow;
        for (uint i = 0; i < allMarkets.length; i++) {
            CTokenInterface ctoken = CTokenInterface(allMarkets[i]);
            if (allMarkets[i] == getCdaiAddress()) {
                supply = wmul(ctoken.balanceOf(getDsaAddress()), ctoken.exchangeRateCurrent());
            }
            borrow = ctoken.borrowBalanceCurrent(getDsaAddress());

            if (allMarkets[i] != getCdaiAddress()) {
                require(borrow == 0, "assets");
            } else {
                require(wdiv(borrow, supply) < 745 * 10 ** 15, "position-risky"); // DAI ratio - should be less than 74.5%
            }
        }
    }

    function maxComp(uint flashAmt, uint route, address[] calldata _targets, bytes[] calldata _data) external {
        address compoundConnect = getCompoundConnectAddress();
        address flashloanConnect = getFlashloanConnectAddress();
        for (uint i = 0; i < _targets.length; i++) {
            require(_targets[i] == compoundConnect || _targets[i] == flashloanConnect, "not-authorised-connector");
        }
        bytes memory _dataEncode = abi.encode(_targets, _data);
        address[] memory _targetFlash = new address[](1);
        bytes[] memory _dataFlash = new bytes[](1);
        _targetFlash[0] = flashloanConnect;
        _dataFlash[0] = abi.encodeWithSignature("flashBorrowAndCast(address,uint256,uint256,bytes)", getDaiAddress(), flashAmt, route, _dataEncode);
        DSAInterface(getDsaAddress()).cast(_targetFlash, _dataFlash, getOriginAddress());
        checkCompoundAssets();
    }

    function claimComp(address[] calldata tokens) external {
        address[] memory _target = new address[](1);
        bytes[] memory _data = new bytes[](1);
        _target[0] = getCompConnectAddress();
        _data[0] = abi.encodeWithSignature("ClaimCompTwo(address[],uint256)", tokens, 0);
        DSAInterface(getDsaAddress()).cast(_target, _data, getOriginAddress());
    }

    function swapComp(uint amt, uint unitAmt) external {
        address[] memory _target = new address[](1);
        bytes[] memory _data = new bytes[](1);
        _target[0] = getUniswapConnectAddress();
        _data[0] = abi.encodeWithSignature("sell(address,address,unit256,unit256,unit256,unit256)", getEthAddress(), getCompAddress(), amt, unitAmt, 0, 0);
        DSAInterface(getDsaAddress()).cast(_target, _data, getOriginAddress());
    }
}
