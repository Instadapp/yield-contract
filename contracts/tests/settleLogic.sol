pragma solidity ^0.6.0;

interface PoolInterface {
    function setExchangeRate() external;
}
contract SettleLogic {
    function calculateExchangeRate(address pool) external {
       PoolInterface(pool).setExchangeRate();
    }
}