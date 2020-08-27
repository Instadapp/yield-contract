// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { DSMath } from "./libs/safeMath.sol";

interface AccountInterface {
  function enable(address authority) external;
  function cast(address[] calldata _targets, bytes[] calldata _datas, address _origin) external payable;
}

interface IndexInterface {
  function master() external view returns (address);
  function build(address _owner, uint accountVersion, address _origin) external returns (address _account);
}

interface RegistryInterface {
  function chief(address) external view returns (bool);
  function poolLogic(address) external returns (address);
  function poolCap(address) external view returns (uint);
  function insureFee(address) external view returns (uint);
  function isDsa(address, address) external view returns (bool);
}

interface RateInterface {
  function getTotalToken() external returns (uint totalUnderlyingTkn);
}

contract PoolToken is ReentrancyGuard, DSMath, ERC20Pausable {
    function convert36To18(uint _dec, uint256 _amt) public pure returns (uint256 amt) {
        amt = (_amt / 10 ** (18 - _dec));
    }

    function convert18To36(uint _dec, uint256 _amt) public pure returns (uint256 amt) {
        amt = mul(_amt, 10 ** (18 - _dec));
    }

    function convertDecTo18(uint _dec, uint256 _amt) internal pure returns (uint256 amt) {
        amt = mul(_amt, 10 ** (18 - _dec));
    }



    using SafeERC20 for IERC20;

    event LogDeploy(uint amount);
    event LogExchangeRate(uint exchangeRate, uint tokenBalance, uint insuranceAmt);
    event LogSettle(uint settleTime);
    event LogDeposit(uint depositAmt, uint poolMintAmt);
    event LogWithdraw(uint withdrawAmt, uint poolBurnAmt);
    event LogAddInsurance(uint amount);
    event LogPausePool(bool);

    IERC20 public immutable baseToken; // Base token. Eg:- DAI, USDC, etc.
    uint256 public immutable baseDecimal; // Base token. Eg:- DAI, USDC, etc.
    RegistryInterface public immutable registry; // Pool Registry
    IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723); // Main Index

    uint private tokenBalance; // total token balance since last rebalancing
    uint public exchangeRate; // initial 1 token = 1
    uint public insuranceAmt; // insurance amount to keep pool safe

    constructor(
        address _registry,
        string memory _name,
        string memory _symbol,
        address _baseToken
    ) public ERC20(_name, _symbol) {
        baseToken = IERC20(_baseToken);
        baseDecimal = ERC20(_baseToken).decimals();
        registry = RegistryInterface(_registry);
        exchangeRate = 10 ** uint(36 - ERC20(_baseToken).decimals());
    }

    modifier isChief() {
        require(registry.chief(msg.sender) || msg.sender == instaIndex.master(), "not-chief");
        _;
    }

    function deploy(address _dsa, uint amount) public isChief {
      require(registry.isDsa(address(this), _dsa), "not-autheticated-dsa");
      baseToken.safeTransfer(_dsa, amount);
      emit LogDeploy(amount);
    }

    function setExchangeRate() public isChief {
      uint _previousRate = convert36To18(baseDecimal, exchangeRate);
      uint _totalToken = RateInterface(registry.poolLogic(address(this))).getTotalToken();
      uint _currentRate = convertDecTo18(baseDecimal, wdiv(_totalToken, totalSupply()));
      if (_currentRate < _previousRate) {
        uint difTkn = sub(tokenBalance, _totalToken);
        insuranceAmt = sub(insuranceAmt, difTkn);
        _currentRate = _previousRate;
      } else {
        uint fee = registry.insureFee(address(this));
        uint difRate = _currentRate - _previousRate;
        uint insureFee = wmul(difRate, fee);
        uint insureFeeAmt = wmul(sub(_totalToken, tokenBalance), fee);
        insuranceAmt = add(insuranceAmt, insureFeeAmt);
        _currentRate = sub(_currentRate, insureFee);
        tokenBalance = sub(_totalToken, insuranceAmt);
      }
      exchangeRate = convert18To36(baseDecimal, _currentRate);
      emit LogExchangeRate(exchangeRate, tokenBalance, insuranceAmt);
    }

    function settle(address _dsa, address[] calldata _targets, bytes[] calldata _datas, address _origin) external isChief {
      require(registry.isDsa(address(this), _dsa), "not-autheticated-dsa");
      if (_targets.length > 0 && _datas.length > 0) {
        AccountInterface(_dsa).cast(_targets, _datas, _origin);
      }
      setExchangeRate();
      emit LogSettle(block.timestamp);
    }

    function deposit(uint tknAmt) external whenNotPaused payable returns(uint) {
      uint _newTokenBal = add(tokenBalance, tknAmt);
      require(_newTokenBal <= registry.poolCap(address(this)), "deposit-cap-reached");

      baseToken.safeTransferFrom(msg.sender, address(this), tknAmt);
      uint _mintAmt = wdiv(tknAmt, exchangeRate);
      _mint(msg.sender, _mintAmt);

      emit LogDeposit(tknAmt, _mintAmt);
    }

    function withdraw(uint tknAmt, address to) external nonReentrant whenNotPaused returns (uint _tknAmt) {
      uint poolBal = baseToken.balanceOf(address(this));
      require(tknAmt <= poolBal, "not-enough-liquidity-available");
      uint _bal = balanceOf(msg.sender);
      uint _tknBal = wmul(_bal, exchangeRate);
      uint _burnAmt;
      if (tknAmt == uint(-1)) {
        _burnAmt = _bal;
        _tknAmt = wmul(_burnAmt, exchangeRate);
      } else {
        require(tknAmt <= _tknBal, "balance-exceeded");
        _burnAmt = wdiv(tknAmt, exchangeRate);
        _tknAmt = tknAmt;
      }

      _burn(msg.sender, _burnAmt);

      baseToken.safeTransfer(to, _tknAmt);

      emit LogWithdraw(tknAmt, _burnAmt);
    }

    function addInsurance(uint tknAmt) external payable {
      baseToken.safeTransferFrom(msg.sender, address(this), tknAmt);
      insuranceAmt += tknAmt;
      emit LogAddInsurance(tknAmt);
    }

    function shutdown() external {
      require(msg.sender == instaIndex.master(), "not-master");
      paused() ? _unpause() : _pause();
    }
}
