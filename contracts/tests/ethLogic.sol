// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

contract EthRateLogic {
    address poolToken;
    
    function getTotalToken() public returns (uint) {
        uint bal = (address(this).balance);
        bal += (address(poolToken).balance);
        return bal;
    }

    function reduceETH(uint amt) public {
        payable(address(0)).transfer(amt);
    }

    constructor (address ethPool) public {
        poolToken = address(ethPool);
    }
}