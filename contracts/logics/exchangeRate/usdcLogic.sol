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

interface ManagerLike {
    function ilks(uint) external view returns (bytes32);
    function owns(uint) external view returns (address);
    function urns(uint) external view returns (address);
    function vat() external view returns (address);
}

interface VatLike {
    function ilks(bytes32) external view returns (uint, uint, uint, uint, uint);
    function dai(address) external view returns (uint);
    function urns(bytes32, address) external view returns (uint, uint);
    function gem(bytes32, address) external view returns (uint);
}


contract UsdcRateLogic is DSMath {
    address public immutable poolToken;
    address public immutable dsa;

    uint public immutable vaultId;
    address public immutable vaultUrn;

    address public constant ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant daiAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant usdcAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public constant PriceFeedAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);

    address public constant compTrollerAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);
    address public constant cethAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);
    
    address public constant curve3poolAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);
    address public constant curve3poolTokenAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);

    address public constant managerAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);
    bytes32 public constant usdcAIlk = bytes32(0);


    function getMakerNetAssetsInEth() private view returns (uint256 _netBal) {
        ManagerLike managerContract =  ManagerLike(managerAddr);
        VatLike vatContract = VatLike(managerContract.vat());
        uint daiPriceInETH = PriceFeedInterface(PriceFeedAddr).getPrice(daiAddr);
        uint usdcPriceInETH = PriceFeedInterface(PriceFeedAddr).getPrice(usdcAddr);

        (uint coll, uint art) = vatContract.urns(usdcAIlk, vaultUrn);
        (,uint rate,,,) = vatContract.ilks(usdcAIlk);
        uint debt = rmul(art, rate);

        uint debtInEth = wmul(debt, daiPriceInETH);
        uint collInEth = wmul(coll, usdcPriceInETH);
        return sub(collInEth, debtInEth);

    }

    function getCompoundNetAssetsInEth(address _dsa) private returns (uint256 _netBalInEth) {
        uint totalSupplyInETH;
        uint totalBorrowInETH;
        address[] memory allMarkets = CompTroller(compTrollerAddr).getAllMarkets();
        PriceFeedInterface priceFeedContract = PriceFeedInterface(PriceFeedAddr);

        for (uint i = 0; i < allMarkets.length; i++) {
            CTokenInterface ctoken = CTokenInterface(allMarkets[i]);
            uint tokenPriceInETH = address(ctoken) == cethAddr ? 10 ** 18 : priceFeedContract.getPrice(ctoken.underlying());
            uint supply = wmul(ctoken.balanceOf(_dsa), ctoken.exchangeRateCurrent());
            uint supplyInETH = wmul(supply, tokenPriceInETH);

            uint borrow = ctoken.borrowBalanceCurrent(_dsa);
            uint borrowInETH = wmul(borrow, tokenPriceInETH);

            totalSupplyInETH += add(totalSupplyInETH, supplyInETH);
            totalBorrowInETH = add(totalBorrowInETH, borrowInETH);
        }
        _netBalInEth = sub(totalSupplyInETH, totalBorrowInETH);
    }

    function getCurveNetAssetsInEth(address _dsa) private view returns (uint256 _netBalInEth) {
        PriceFeedInterface priceFeedContract = PriceFeedInterface(PriceFeedAddr);
        uint ethPriceUSD = priceFeedContract.getEthPrice();
        uint virtualPrice = ICurve(curve3poolAddr).get_virtual_price();
        uint curveTokenBal = TokenInterface(curve3poolTokenAddr).balanceOf(_dsa);
        uint amtInUSD = wmul(curveTokenBal, virtualPrice);
        uint amtInETH = wdiv(amtInUSD, ethPriceUSD);
        _netBalInEth = add(_netBalInEth, amtInETH);
    }

    function getNetDsaAssetsInEth(address _dsa) private returns (uint256 _netBalInEth) {
        _netBalInEth += getCompoundNetAssetsInEth(_dsa);
        _netBalInEth += getMakerNetAssetsInEth();
        _netBalInEth += getCurveNetAssetsInEth(_dsa);
    }
    
    function getTotalToken() public returns (uint256 usdcBal) {
        address _dsa = 0x0000000000000000000000000000000000000000;
        PriceFeedInterface priceFeedContract = PriceFeedInterface(PriceFeedAddr);
        uint usdcPriceInETH = priceFeedContract.getPrice(usdcAddr);
        
        TokenInterface usdcToken = TokenInterface(usdcAddr);
        usdcBal = usdcToken.balanceOf(_dsa);
        usdcBal += TokenInterface(usdcAddr).balanceOf(poolToken);

        uint balInEth = getNetDsaAssetsInEth(_dsa);
        usdcBal += wdiv(balInEth, usdcPriceInETH);
    }


    constructor (address usdcPool, address _dsa, uint _vaultId) public {
        poolToken = address(usdcPool);
        vaultId = _vaultId;
        dsa = _dsa;
        vaultUrn = ManagerLike(managerAddr).urns(_vaultId);
    }
}