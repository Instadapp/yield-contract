// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import { DSMath } from "../../libs/safeMath.sol";

interface CTokenInterface {
    function borrowBalanceCurrent(address account) external returns (uint256);
    function exchangeRateCurrent() external returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function underlying() external view returns (address);
}

interface DSAInterface {
    function cast(address[] calldata _targets, bytes[] calldata _datas, address _origin) external payable;
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

contract LogicOne {

    address public constant compTrollerAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);
    address public constant cethAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);
    address public constant cdaiAddr = address(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    address public constant ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant compOracleAddr = address(0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88);

    function getCompoundNetAssetsInEth(address _dsa) private returns (uint256 _netBal) {
        uint totalSupplyInETH;
        uint totalBorrowInETH;
        address[] memory allMarkets = CompTroller(compTrollerAddr).getAllMarkets();
        OracleComp priceFeedContract = OracleComp(compOracleAddr);
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

            if (allMarkets[i] != cdaiAddr && allMarkets[i] != cethAddr) {
                require(supply == 0 && borrow == 0, "assets");
            }
            // require()
        }
        _netBal = sub(totalSupplyInETH, totalBorrowInETH);
    }

    function maxComp(address _dsa, address[] calldata _targets, bytes[] calldata _data) public {
        // check if DSA is authorised for interaction
        // Also think on dydx flash loan connector
        // initial Compound position borrow and supply
        address compoundConnector = address(0); // Check9898 - address of compound connector
        address instaPoolConnector = address(0); // Check9898 - address of instaPool connector
        for (uint i = 0; i < _targets.length; i++) {
            require(_targets[i] == compoundConnector || _targets[i] == instaPoolConnector, "connector-not-authorised");
        }
        DSAInterface(_dsa).cast(_targets, _data, address(0)); // Check9898 - address of basic connector
        // final Compound position borrow and supply
        // check the chnages should only be in eth supply & dai
        // check if status is safe and only have assets in the specific tokens
    }

    receive() external payable {}

}
