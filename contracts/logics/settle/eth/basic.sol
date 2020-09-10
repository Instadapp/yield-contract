// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import { DSMath } from "../../../libs/safeMath.sol";

contract LogicOne {

    address poolToken;

    function deploy(address _dsa, uint amt) public {
        // check if DSA is authorised
        // transfer assets to DSA
    }

    function redeem(address _dsa, uint amt) public {
        // withdraw assets from DSA
    }

    constructor (address ethPool) public {
        poolToken = address(ethPool);
    }

    receive() external payable {}

}
