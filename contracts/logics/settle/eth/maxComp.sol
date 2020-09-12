// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import { DSMath } from "../../../libs/safeMath.sol";

interface DSAInterface {
    function cast(address[] calldata _targets, bytes[] calldata _datas, address _origin) external payable;
}

contract LogicOne {

    function maxComp(address _dsa, address[] calldata _targets, bytes[] calldata _data) public {
        // check if DSA is authorised for interaction
        // Also think on dydx flash loan connector
        address compoundConnector = address(0); // Check9898 - address of compound connector
        address instaPoolConnector = address(0); // Check9898 - address of instaPool connector
        for (uint i = 0; i < _targets.length; i++) {
            require(_targets[i] == compoundConnector || _targets[i] == instaPoolConnector, "connector-not-authorised");
        }
        DSAInterface(_dsa).cast(_targets, _data, address(0)); // Check9898 - address of basic connector
        // check if status is safe and only have assets in the specific tokens
    }

    receive() external payable {}

}
