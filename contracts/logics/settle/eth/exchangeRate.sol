// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import { DSMath } from "../../../libs/safeMath.sol";

interface PoolInterface {
    function setExchangeRate() external;
}

contract LogicOne {

    function setExchangeRate() public payable {
        PoolInterface(address(this)).setExchangeRate();
    }

    receive() external payable {}

}
