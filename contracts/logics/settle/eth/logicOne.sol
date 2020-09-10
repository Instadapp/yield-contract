// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import { DSMath } from "../../../libs/safeMath.sol";

contract LogicOne {

    address poolToken;

    function maxComp(uint amt) public {
        // open cast function with flashloan and Compound connectors access
        // check if status is safe and only have assets in the specific tokens
    }

    function unwindCompToSafe(uint amt) public {
        // Will only uniwnd till safe limit
        // open cast function with flashloan and Compound connectors access
        // check if status is safe and only have assets in the specific tokens
    }

    function unwindMaxComp(uint amt) public {
        // open cast function with flashloan and Compound connectors access
        // check if status is safe and only have assets in the specific tokens
    }

    constructor (address ethPool) public {
        poolToken = address(ethPool);
    }

    receive() external payable {}

}
