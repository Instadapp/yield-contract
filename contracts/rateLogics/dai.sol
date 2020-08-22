// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import { DSMath } from "../libs/safeMath.sol";

interface PoolTokenInterface {
  function totalBalance() external view returns (uint);
  function dsaAmount() external view returns (uint);
  function totalSupply() external view returns (uint);

}

interface ATokenInterface {
  function balanceOf(address) external view returns (uint);
}

interface CTokenInterface {
  function getExchangeRate() external view returns (uint);
  function balanceOf(address) external view returns (uint);
}

contract RateLogic is DSMath {
    PoolTokenInterface poolToken = PoolTokenInterface(address(0));
    ATokenInterface atoken = ATokenInterface(address(0));
    CTokenInterface ctoken = CTokenInterface(address(0));
    CTokenInterface token = CTokenInterface(address(0));

    uint fee = 1e17; // 10%
    function totalBalanceDSA() public view returns (uint) {
        address _dsa;
        uint abal = atoken.balanceOf(_dsa);
        uint cbal = wmul(ctoken.balanceOf(_dsa), ctoken.getExchangeRate());
        uint bal = token.balanceOf(_dsa);
        return add(abal, add(cbal, bal));
    }

    function totalBalance() public view returns (uint) {
        address _dsa;
        uint abal = atoken.balanceOf(_dsa);
        uint cbal = wmul(ctoken.balanceOf(_dsa), ctoken.getExchangeRate());
        uint dsaBal = token.balanceOf(_dsa);
        uint poolBal = token.balanceOf(address(poolToken));
        return add(add(abal, poolBal) , add(cbal, dsaBal));
    }

    function pricePerToken() public view returns(uint256) {
        // TODO - add security logic
        uint _totalBalance = totalBalanceDSA();
        uint profit = sub(_totalBalance, poolToken.dsaAmount());
        uint leftProfit = wmul(profit, fee);
        uint leftTotalBalance = add(leftProfit, poolToken.dsaAmount());
        return wdiv(leftTotalBalance, poolToken.totalSupply());
    }
}
