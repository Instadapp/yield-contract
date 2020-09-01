// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

interface TokenInterface {
    function balanceOf(address) external view returns (uint);
    function transfer(address, uint) external returns (bool);
}

contract DaiRateLogic {
    address poolToken;
    
    TokenInterface baseToken;

    function getTotalToken() public returns (uint) {
        uint bal = baseToken.balanceOf(address(this));
        bal += baseToken.balanceOf(address(poolToken));
        return bal;
    }

    function reduceDai(uint amt) public {
        baseToken.transfer(address(this), amt);
    }

    constructor (address daiPool, address dai) public {
        poolToken = address(daiPool);
        baseToken = TokenInterface(address(dai));
    }
}