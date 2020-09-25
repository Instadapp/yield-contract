// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DSMath } from "../../../libs/safeMath.sol";

interface DSAInterface {
    function cast(address[] calldata _targets, bytes[] calldata _data, address _origin) external payable;
}

contract LogicOne {

    using SafeERC20 for IERC20;

    /**
        * @dev Return ethereum address
    */
    function getEthAddr() internal pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // ETH Address
    }

    function getOriginAddress() private pure returns(address) {
        return 0xB7fA44c2E964B6EB24893f7082Ecc08c8d0c0F87; // DSA address
    }

    function deploy(address _dsa, address _token, uint amt) public {
        // check if DSA is authorised
        if (_token == getEthAddr()) {
            uint _bal = address(this).balance;
            amt = amt > _bal ? _bal : amt;
            payable(_dsa).transfer(amt);
        } else {
            IERC20 token = IERC20(_token);
            uint _bal = token.balanceOf(address(this));
            amt = amt > _bal ? _bal : amt;
            token.safeTransfer(_dsa, amt);
        }
        // emit event?
    }

    // withdraw assets from DSA
    function redeem(address _dsa, address _token, uint amt) public {
        uint _bal = IERC20(_token).balanceOf(_dsa);
        amt = amt > _bal ? _bal : amt;
        address[] memory _targets = new address[](1);
        _targets[0] = address(0); // Check9898 - address of basic connector
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encodeWithSignature("withdraw(address,uint256,address,uint256,uint256)", _token, amt, address(this), uint(0), uint(0));
        DSAInterface(_dsa).cast(_targets, _data, getOriginAddress());
    }

    constructor () public {}

    receive() external payable {}

}
