// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PoolToken is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol
    ) public ERC20(_name, _symbol) {
        // TODO - 0
    }
}
