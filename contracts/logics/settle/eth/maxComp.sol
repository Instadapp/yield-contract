// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import { DSMath } from "../../../libs/safeMath.sol";

interface DSAInterface {
    function cast(address[] calldata _targets, bytes[] calldata _datas, address _origin) external payable;
}

contract LogicOne {

    address poolToken;
    DSAInterface dsa;

    function maxComp(address[] calldata _targets, bytes[] calldata _data) public {
        address compoundConnector = address(0);
        address instaPoolConnector = address(0);
        for (uint i = 0; i < _targets.length; i++) {
            require(_targets[i] == compoundConnector || _targets[i] == instaPoolConnector, "connector-not-authorised");
        }
        dsa.cast(_targets, _data, address(0));
        // check if status is safe and only have assets in the specific tokens
    }

    constructor (address ethPool, address _dsa) public {
        poolToken = ethPool;
        dsa = DSAInterface(_dsa);
    }

    receive() external payable {}

}
