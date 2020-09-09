pragma solidity ^0.6.0;

interface TokenInterface {
    function approve(address, uint) external;
    function transfer(address, uint) external;
    function transferFrom(address, address, uint) external;
    function deposit() external payable;
    function withdraw(uint) external;
    function balanceOf(address) external view returns (uint);
}

interface TokenPool {
    function deposit(uint amount) external payable returns (uint);
    function withdraw(uint amount, address to) external returns (uint);
}

interface Registry {
    function poolToken(address) external view returns (address);
}

contract BasicProxy {
    function getRegistryAddr() internal pure returns (address) {
        return 0x53A664d8F4FF1201eA9415825a746D1652345110;
    }
    
    function getEthAddr() internal pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }
    
    function deposit(address token, uint amount) external payable {
       Registry registry = Registry(getRegistryAddr());
       address tokenPoolAddr = registry.poolToken(token);
       require(tokenPoolAddr != address(0), "Token-pool-not-found");
       uint bal = getEthAddr() == token ? address(this).balance : TokenInterface(token).balanceOf(address(this));
       uint _amt = amount >= bal ? bal : amount;
       uint ethAmt = getEthAddr() == token ? _amt : 0;
       TokenPool(tokenPoolAddr).deposit.value(ethAmt)(amount);
    }

    function withdraw(address token, uint amount, address to) external {
       Registry registry = Registry(getRegistryAddr());
       address tokenPoolAddr = registry.poolToken(token);
       require(tokenPoolAddr != address(0), "Token-pool-not-found");
       TokenPool(tokenPoolAddr).withdraw(amount, to);
    }
}