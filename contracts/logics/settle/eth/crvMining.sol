// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import { DSMath } from "../../../libs/safeMath.sol";

contract LogicOne {

    // borrow from Compound & deposit in Curve (static logic for DAI)
    function compCrvMine(address token, uint amt, uint unitAmt, string calldata guage) public {
        address[] memory _targets = new address[](3);
        bytes[] memory _data = new bytes[](3);
        _targets[0] = address(0); // Check9898 - address of compound connector
        _data[0] = abi.encodeWithSignature("borrow(address,uint256,uint256,uint256)", token, amt, uint(0), uint(0));
        _targets[1] = address(0); // Check9898 - address of curve connector
        _data[1] = abi.encodeWithSignature("deposit(address,uint256,uint256,uint256,uint256)", token, amt, unitAmt, uint(0), uint(0));
        _targets[2] = address(0); // Check9898 - address of curve guage connector
        _data[2] = abi.encodeWithSignature("deposit(string,uint256,uint256,uint256)", guage, uint(-1), uint(0), uint(0));
        // check if status is safe and only have assets in the specific tokens
    }

    function compCrvRedeem(address token, uint amt, uint unitAmt, string calldata guage) public {
        // Withdraw from Curve and payback on Compound
        address[] memory _targets;
        bytes[] memory _data;
        if (amt == uint(-1)) {
            _targets = new address[](3);
            _data = new bytes[](3);
        } else {
            _targets = new address[](4);
            _data = new bytes[](4);
        }
        _targets[0] = address(0); // Check9898 - address of curve guage connector
        _data[0] = abi.encodeWithSignature("withdraw(string,uint256,uint256,uint256,uint256,uint256)", guage, uint(-1), uint(0), uint(0), uint(0), uint(0));
        _targets[1] = address(0); // Check9898 - address of curve connector
        _data[1] = abi.encodeWithSignature("withdraw(address,uint256,uint256,uint256,uint256)", token, amt, unitAmt, uint(0), uint(0));
        _targets[2] = address(0); // Check9898 - address of compound connector
        _data[2] = abi.encodeWithSignature("payback(address,uint256,uint256,uint256)", token, amt, uint(0), uint(0));
        if (amt != uint(-1)) {
            _targets[3] = address(0); // Check9898 - address of curve guage connector
            _data[3] = abi.encodeWithSignature("deposit(string,uint256,uint256,uint256)", guage, uint(-1), uint(0), uint(0));
        }
    }

    receive() external payable {}

}
