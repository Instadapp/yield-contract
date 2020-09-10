// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import { DSMath } from "../../../libs/safeMath.sol";

contract LogicOne {

    address poolToken;

    function setExchangeRate() public {
        // run setExchangeRate in address(this)
    }

    constructor (address ethPool) public {
        poolToken = address(ethPool);
    }

    receive() external payable {}

}
