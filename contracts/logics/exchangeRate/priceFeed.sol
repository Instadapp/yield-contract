pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface ChainLinkInterface {
    function latestAnswer() external view returns (int256);
    function decimals() external view returns (uint256);
}

interface IndexInterface {
  function master() external view returns (address);
}

interface TokenInterface {
  function decimals() external view returns (uint);
}

import { DSMath } from "../../libs/safeMath.sol";


contract Basic is DSMath {
    address public constant instaIndex = 0x2971AdFa57b20E5a416aE5a708A8655A9c74f723;
    address public constant ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    modifier isChief {
        require(
        IndexInterface(instaIndex).master() == msg.sender, "not-Chief");
        _;
    }

    event LogAddChainLinkMapping(
        address tokenSymbol,
        address chainlinkFeed
    );

    event LogRemoveChainLinkMapping(
        address tokenSymbol,
        address chainlinkFeed
    );

    struct FeedData {
        address feedAddress;
        uint multiplier;
    }

    mapping (address => FeedData) public chainLinkMapping;


    function convertPrice(uint price, uint multiplier) internal pure returns (uint) {
        return price * (10 ** multiplier);
    }

    function _addChainLinkMapping(
        address token,
        address chainlinkFeed
    ) internal {
        require(token != address(0), "token-not-vaild");
        require(chainlinkFeed != address(0), "chainlinkFeed-not-vaild");
        require(chainLinkMapping[token].feedAddress == address(0), "chainlinkFeed-already-added");
        uint tokenDec = token == ethAddr ? 18 : TokenInterface(token).decimals();
        uint feedDec = ChainLinkInterface(chainlinkFeed).decimals();
        
        chainLinkMapping[token].feedAddress = chainlinkFeed;
        chainLinkMapping[token].multiplier = sub(36, add(tokenDec, feedDec));
        emit LogAddChainLinkMapping(token, chainlinkFeed);
    }

    function _removeChainLinkMapping(address token) internal {
        require(token != address(0), "token-not-vaild");
        require(chainLinkMapping[token].feedAddress != address(0), "chainlinkFeed-not-added-yet");

        emit LogRemoveChainLinkMapping(token, chainLinkMapping[token].feedAddress);
        delete chainLinkMapping[token];
    }

    function addChainLinkMapping(
        address[] memory tokens,
        address[] memory chainlinkFeeds
    ) public isChief {
        require(tokens.length == chainlinkFeeds.length, "lenght-not-same");
        for (uint i = 0; i < tokens.length; i++) {
            _addChainLinkMapping(tokens[i], chainlinkFeeds[i]);
        }
    }

    function removeChainLinkMapping(address[] memory tokens) public isChief {
        for (uint i = 0; i < tokens.length; i++) {
            _removeChainLinkMapping(tokens[i]);
        }
    }
}

contract Resolver is Basic {
    function getPrices(address[] memory tokens)
    public
    view
    returns (
        uint[] memory tokensPriceInETH
    ) {
        tokensPriceInETH = new uint[](tokens.length);
        for (uint i = 0; i < tokens.length; i++) {
            if (tokens[i] != ethAddr) {
                FeedData memory feedData = chainLinkMapping[tokens[i]];
                ChainLinkInterface feedContract = ChainLinkInterface(feedData.feedAddress);
                require(address(feedContract) != address(0), "price-not-found");
                tokensPriceInETH[i] = convertPrice(uint(feedContract.latestAnswer()), feedData.multiplier);
            } else {
                tokensPriceInETH[i] = 10 ** 18;
            }
        }
    }

    function getPrice(address token)
    public
    view
    returns (
        uint tokenPriceInETH
    ) { 
        if (token != ethAddr) {
            FeedData memory tokenFeedData = chainLinkMapping[token];
            ChainLinkInterface tokenFeed = ChainLinkInterface(tokenFeedData.feedAddress);
            require(address(tokenFeed) != address(0), "price-not-found");
            tokenPriceInETH = convertPrice(uint(tokenFeed.latestAnswer()), tokenFeedData.multiplier);
        } else {
            tokenPriceInETH = 10 ** 18;
        }
    }

    function getEthPrice()
    public
    view
    returns (
        uint ethPriceInUsd
    ) { 
        FeedData memory ethFeedData = chainLinkMapping[ethAddr];
        ChainLinkInterface ethFeed = ChainLinkInterface(ethFeedData.feedAddress);
        ethPriceInUsd = convertPrice(uint(ethFeed.latestAnswer()), ethFeedData.multiplier);
    }
}

contract ChainLinkPriceFeed is Resolver {
    constructor (address[] memory tokens, address[] memory chainlinkFeeds) public {
        require(tokens.length == chainlinkFeeds.length, "Lenght-not-same");
        for (uint i = 0; i < tokens.length; i++) {
            _addChainLinkMapping(tokens[i], chainlinkFeeds[i]);
        }
    }
}