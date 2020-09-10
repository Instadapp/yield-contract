// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import { DSMath } from "../../libs/safeMath.sol";

contract EthRateLogic {
    address poolToken;

    function getCompoundNetAssetsInEth(address _dsa) private returns (uint _netBal) {
        // Logics
        // Take price from Compound's Oracle?
    }

    function getCurveNetAssetsInEth(address _dsa) private returns (uint _netBal) {
        // Logics
        // Take price from ChainLink's Oracle?
    }

    function getNetDsaAssets(address _dsa) private returns (uint _netBal) {
        _netBal = _dsa.balance;
        _netBal += getCompoundNetAssetsInEth(_dsa);
        _netBal += getCurveNetAssetsInEth(_dsa);
    }
    
    function getTotalToken() public returns (uint) {
        address _dsa = 0x0000000000000000000000000000000000000000;
        uint bal = poolToken.balance;
        bal += getNetDsaAssets(_dsa);
        return bal;
    }

    function reduceETH(uint amt) public {
        payable(address(0)).transfer(amt);
    }

    constructor (address ethPool) public {
        poolToken = address(ethPool);
    }

    receive() external payable {}
}