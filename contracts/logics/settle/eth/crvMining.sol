// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import { DSMath } from "../../../libs/safeMath.sol";

contract LogicOne {

    function compCrvMine(uint amt) public {
        // borrow from Compound & deposit in Curve (static logic for DAI)
        // check if status is safe and only have assets in the specific tokens
    }

    function compCrvRedeem(uint amt) public {
        // Withdraw from Curve and payback on Compound
    }

    receive() external payable {}

}
