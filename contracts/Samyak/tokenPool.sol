// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import { DSMath } from "./../libs/safeMath.sol";

// TODO - Add ReentrancyGuard lib

interface AccountInterface {
  function enable(address authority) external;
  function cast(address[] calldata _targets, bytes[] calldata _datas, address _origin) external payable;
}

interface IndexInterface {
  function master() external view returns (address);
}

interface RegistryInterface {
  function chief(address) external view returns (bool);
  function dsa(address) external view returns (address);
  function rateLogic(address) external view returns (address);
}

interface RateInterface {
  function pricePerToken() external view returns (uint);
  function totalBalance() external view returns (uint);
  function getTotalToken() external returns (uint totalUnderlyingTkn);
}

contract PoolToken is ERC20, DSMath {
    using SafeERC20 for IERC20;

    IERC20 public immutable baseToken;
    RegistryInterface public immutable registry;
    IndexInterface public immutable instaIndex;

    uint private tokenBalance;
    uint private tokenProfit;
    uint private tokenCap;
    uint public exchangeRate = 1000000000000000000; // initial 1 token = 1
    address public settlementLogic;
    uint public insuranceAmt;
    
    constructor(
        address _registry,
        address _index,
        string memory _name,
        string memory _symbol,
        address _baseToken
    ) public ERC20(_name, _symbol) {
        // TODO - 0
        baseToken = IERC20(_baseToken);
        registry = RegistryInterface(_registry);
        instaIndex = IndexInterface(_index);
    }

    modifier isMaster() {
        require(msg.sender == instaIndex.master(), "not-master");
        _;
    }

    modifier isChief() {
        require(registry.chief(msg.sender) || msg.sender == instaIndex.master(), "not-chief");
        _;
    }
    
    uint dsaAmount;
    function deploy(uint amount) public isChief {
        address _dsa = registry.dsa(address(this));
        baseToken.safeTransfer(_dsa, amount);
        dsaAmount = add(dsaAmount, amount);
    }

    function claim(uint amount) public isChief {
        // address _dsa = registry.dsa(address(this));
        baseToken.safeTransferFrom(msg.sender, address(this), amount);
        uint totalAmountWithProfit = RateInterface(address(0)).totalBalance(); // TODO - change to => totalBalanceDSA
        uint _amount = wdiv(wmul(amount, dsaAmount), totalAmountWithProfit);
        uint profit = sub(amount, _amount);
        tokenProfit = add(tokenProfit, profit);
        dsaAmount = sub(dsaAmount, _amount);
    }

    function getBalance() public view returns(uint) {
        return sub(add(dsaAmount, baseToken.balanceOf(address(this))), tokenProfit);
    }

    function pricePerToken() public view returns(uint) {
        return 1e18; // TODO - Link to rate logic contract
    }

    function setExchangeRate() public view isChief {
        uint _previousRate = exchangeRate;
        uint _totalToken = RateInterface(settlementLogic).getTotalToken();
        uint _currentRate = wdiv(_totalToken, totalSupply());
        if (_currentRate < _previousRate) {
            uint difRate = _previousRate - _currentRate;
            uint difTkn = wmul(_totalToken, difRate);
            insuranceAmt = sub(insuranceAmt, difTkn);
            _currentRate = _previousRate;
        } else {
            uint difRate = _currentRate - _previousRate;
            uint insureFee = wmul(difRate, 100000000000000000); // 1e17
            uint insureFeeAmt = wmul(_totalToken, insureRate);
            insuranceAmt = add(insuranceAmt, insureFeeAmt);
            _currentRate = sub(_currentRate, insureFee);
        }
        exchangeRate = _currentRate;
    }

    function settlement(address[] calldata _targets, bytes[] calldata _datas, address _origin) external view isChief {
        address _dsa = registry.dsa(address(this));
        if (_targets.length > 0 && _datas.length > 0) {
            AccountInterface(_dsa).cast(_targets, _datas, _origin);
        }
        setExchangeRate();
    }

    function deposit(uint amount) public returns(uint) {
        uint _newTokenBal = add(tokenBalance, amount);
        require(_newTokenBal <= getBalance(), "deposit-cap-reached");

        baseToken.safeTransferFrom(msg.sender, address(this), amount);
        uint iAmt = wdiv(amount, exchangeRate);
        _mint(msg.sender, iAmt);
    }

    function withdraw(address owner, uint iAmount) public returns (uint) {
        // TODO - check balance before withdrawing
        uint amount = wmul(iAmount, exchangeRate);
        _burn(msg.sender, iAmount);

        baseToken.safeTransfer(owner, amount);
    }

    function withdraw(uint amount) public returns (uint) {
        return withdraw(msg.sender, amount);
    }
}