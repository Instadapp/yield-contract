// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import { DSMath } from "../../libs/safeMath.sol";

interface CTokenInterface {
    function borrowBalanceCurrent(address account) external returns (uint256);
    function exchangeRateCurrent() external returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function underlying() external view returns (address);
}

interface CompTroller {
    function getAllMarkets() external view returns (address[] memory);
}

interface OracleComp {
    function getUnderlyingPrice(address) external view returns (uint);
}

interface InstaMapping {
    function cTokenMapping(address) external view returns (address);
}

interface CurveMapping {
    function curvePoolMapping(address poolAddr) external view returns (address);
}

interface CurveRegistry {
    function pool_list(uint) external view returns (address poolAddress, address poolToken);
    function pool_count() external view returns (uint);
}

interface ICurve {
    function get_virtual_price() external view returns (uint256 out);
}

interface TokenInterface {
    function balanceOf(address owner) external view returns (uint256);
}

interface PriceFeedInterface {
    function getPrices(address[] memory tokens) external view returns (uint256[] memory pricesInETH);
    function getPrice(address token) external view returns (uint256 priceInETH);
    function getEthPrice() external view returns (uint256 ethPriceUSD);
}


contract EthRateLogic is DSMath {
    address public immutable poolToken;
    address public constant compTrollerAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);
    address public constant cethAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);
    address public constant ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant compOracleAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);
    address public constant PriceFeedAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);
    address public constant ctokenMapping = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);
    address public constant curve3poolAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);
    address public constant curve3poolTokenAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);

    function getCompoundNetAssetsInEth(address _dsa) private returns (uint256 _netBal) {
        uint totalSupplyInETH;
        uint totalBorrowInETH;
        address[] memory allMarkets = CompTroller(compTrollerAddr).getAllMarkets();
        PriceFeedInterface priceFeedContract = PriceFeedInterface(PriceFeedAddr);
        // uint ethPrice = oracleContract.getUnderlyingPrice(cethAddr);
        for (uint i = 0; i < allMarkets.length; i++) {
            CTokenInterface ctoken = CTokenInterface(allMarkets[i]);
            uint tokenPriceInETH = priceFeedContract.getPrice(address(ctoken) == cethAddr ? ethAddr : ctoken.underlying());
            uint supply = wmul(ctoken.balanceOf(_dsa), ctoken.exchangeRateCurrent());
            uint supplyInETH = wmul(supply, tokenPriceInETH);

            uint borrow = ctoken.borrowBalanceCurrent(_dsa);
            uint borrowInETH = wmul(borrow, tokenPriceInETH);

            totalSupplyInETH += add(totalSupplyInETH, supplyInETH);
            totalBorrowInETH = add(totalBorrowInETH, borrowInETH);
        }
        _netBal = sub(totalSupplyInETH, totalBorrowInETH);
    }

    function getCurveNetAssetsInEth(address _dsa) private view returns (uint256 _netBal) {
        PriceFeedInterface priceFeedContract = PriceFeedInterface(PriceFeedAddr);
        uint ethPriceUSD = priceFeedContract.getEthPrice();
        uint virtualPrice = ICurve(curve3poolAddr).get_virtual_price();
        uint curveTokenBal = TokenInterface(curve3poolTokenAddr).balanceOf(_dsa);
        uint amtInUSD = wmul(curveTokenBal, virtualPrice);
        uint amtInETH = wdiv(amtInUSD, ethPriceUSD);
        _netBal = add(_netBal, amtInETH);
    }

    function getNetDsaAssets(address _dsa) private returns (uint256 _netBal) {
        _netBal = _dsa.balance;
        _netBal += getCompoundNetAssetsInEth(_dsa);
        _netBal += getCurveNetAssetsInEth(_dsa);
    }
    
    function getTotalToken() public returns (uint256) {
        address _dsa = 0x0000000000000000000000000000000000000000;
        uint256 bal = poolToken.balance;
        bal += getNetDsaAssets(_dsa);
        return bal;
    }

    constructor (address ethPool) public {
        poolToken = address(ethPool);
    }

    receive() external payable {}
}