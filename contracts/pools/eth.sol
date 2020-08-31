// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { DSMath } from "../libs/safeMath.sol";

interface AccountInterface {
  function isAuth(address) external view returns(bool);
  function cast(address[] calldata _targets, bytes[] calldata _datas, address _origin) external payable;
}

interface IndexInterface {
  function master() external view returns (address);
  function build(address _owner, uint accountVersion, address _origin) external returns (address _account);
}

interface RegistryInterface {
  function chief(address) external view returns (bool);
  function poolLogic(address) external returns (address);
  function insureFee(address) external view returns (uint);
  function withdrawalFee(address) external view returns (uint);
  function isDsa(address, address) external view returns (bool);
}

interface RateInterface {
  function getTotalToken() external returns (uint totalUnderlyingTkn);
}

contract PoolToken is ReentrancyGuard, ERC20Pausable, DSMath {
  using SafeERC20 for IERC20;

  event LogDeploy(address indexed dsa, address indexed token, uint amount);
  event LogExchangeRate(uint exchangeRate, uint tokenBalance, uint insuranceAmt);
  event LogSettle(uint settleBlock);
  event LogDeposit(address indexed user, uint depositAmt, uint poolMintAmt);
  event LogWithdraw(address indexed user, uint withdrawAmt, uint poolBurnAmt, uint feeAmt);
  event LogAddInsurance(uint amount);
  event LogWithdrawInsurance(uint amount);
  event LogPausePool(bool);

  RegistryInterface public immutable registry; // Pool Registry
  IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723);

  IERC20 public immutable baseToken; // Base token.
  uint private tokenBalance; // total token balance
  uint public exchangeRate = 10 ** 18; // initial 1 token = 1
  uint public insuranceAmt; // insurance amount to keep pool safe

  constructor(
    address _registry,
    string memory _name,
    string memory _symbol,
    address _baseToken
  ) public ERC20(_name, _symbol) {
    baseToken = IERC20(_baseToken);
    registry = RegistryInterface(_registry);
  }

  modifier isChief() {
    require(registry.chief(msg.sender) || msg.sender == instaIndex.master(), "not-chief");
    _;
  }

  /**
    * @dev Deploy assets to DSA.
    * @param _dsa DSA address
    * @param token token address
    * @param amount token amount
  */
  function deploy(address _dsa, address token, uint amount) external isChief {
    require(registry.isDsa(address(this), _dsa), "not-autheticated-dsa");
    require(AccountInterface(_dsa).isAuth(address(this)), "token-pool-not-auth");
    if (token == address(0)) { // pool base ETH
      payable(_dsa).transfer(amount);
    } else { // non-pool other tokens
      IERC20(token).safeTransfer(_dsa, amount);
    }
    emit LogDeploy(_dsa, token, amount);
  }

  /**
    * @dev get pool token rate
    * @param tokenAmt total token amount
  */
  function getCurrentRate(uint tokenAmt) public view returns (uint) {
    return wdiv(totalSupply(), tokenAmt);
  }

  /**
    * @dev sets exchange rates
  */
  function setExchangeRate() public isChief {
    uint _previousRate = exchangeRate;
    uint _totalToken = RateInterface(registry.poolLogic(address(this))).getTotalToken();
    _totalToken = sub(_totalToken, insuranceAmt);
    uint _currentRate = getCurrentRate(_totalToken);
    require(_currentRate != 0, "current-rate-is-zero");
    if (_currentRate > _previousRate) { // loss => deduct partially/fully from insurance amount
      uint _loss = sub(tokenBalance, _totalToken);
      if (_loss <= insuranceAmt) {
        insuranceAmt = sub(insuranceAmt, _loss);
        _currentRate = _previousRate;
      } else {
        tokenBalance = add(_totalToken, insuranceAmt);
        insuranceAmt = 0;
        _currentRate = getCurrentRate(tokenBalance);
      }
    } else { // profit => add to insurance amount
      uint insureFeeAmt = wmul(sub(_totalToken, tokenBalance), registry.insureFee(address(this)));
      insuranceAmt = add(insuranceAmt, insureFeeAmt);
      tokenBalance = sub(_totalToken, insureFeeAmt);
      _currentRate = getCurrentRate(tokenBalance);
    }
    exchangeRate = _currentRate;
    emit LogExchangeRate(exchangeRate, tokenBalance, insuranceAmt);
  }

  /**
    * @dev Settle the assets on dsa and update exchange rate
    * @param _dsa DSA address
    * @param _targets array of connector's address
    * @param _datas array of connector's function calldata
    * @param _origin origin address
  */
  function settle(address _dsa, address[] calldata _targets, bytes[] calldata _datas, address _origin) external isChief {
    require(registry.isDsa(address(this), _dsa), "not-autheticated-dsa");
    AccountInterface dsaWallet = AccountInterface(_dsa);
    if (_targets.length > 0 && _datas.length > 0) {
      dsaWallet.cast(_targets, _datas, _origin);
    }
    require(dsaWallet.isAuth(address(this)), "token-pool-not-auth");
    setExchangeRate();
    emit LogSettle(block.number);
  }

  /**
    * @dev Deposit token.
    * @param tknAmt token amount
    * @return _mintAmt amount of wrap token minted
  */
  function deposit(uint tknAmt) public whenNotPaused payable returns (uint _mintAmt) {
    require(tknAmt == msg.value, "unmatched-amount");
    tokenBalance = add(tokenBalance, tknAmt);

    _mintAmt = wmul(msg.value, exchangeRate);
    _mint(msg.sender, _mintAmt);

    emit LogDeposit(msg.sender, tknAmt, _mintAmt);
  }

  /**
    * @dev Withdraw tokens.
    * @param tknAmt token amount
    * @param to withdraw tokens to address
    * @return _tknAmt amount of token withdrawn
  */
  function withdraw(uint tknAmt, address to) external nonReentrant whenNotPaused returns (uint _tknAmt) {
    uint poolBal = address(this).balance;
    require(to != address(0), "to-address-not-vaild");
    require(tknAmt <= poolBal, "not-enough-liquidity-available");
    uint _bal = balanceOf(msg.sender);
    uint _tknBal = wdiv(_bal, exchangeRate);
    uint _burnAmt;
    if (tknAmt >= _tknBal) {
      _burnAmt = _bal;
      _tknAmt = _tknBal;
    } else {
      _burnAmt = wmul(tknAmt, exchangeRate);
      _tknAmt = tknAmt;
    }

    tokenBalance = sub(tokenBalance, _tknAmt);

    _burn(msg.sender, _burnAmt);

    uint _withdrawalFee = registry.withdrawalFee(address(this));
    uint _feeAmt;
    if (_withdrawalFee > 0) {
      _feeAmt = wmul(_tknAmt, _withdrawalFee);
      insuranceAmt = add(insuranceAmt, _feeAmt);
      _tknAmt = sub(_tknAmt, _feeAmt);
    }

    payable(to).transfer(_tknAmt);

    emit LogWithdraw(msg.sender, tknAmt, _burnAmt, _feeAmt);
  }

  /**
    * @dev Add Insurance to the pool.
    * @param tknAmt insurance token amount to add
  */
  function addInsurance(uint tknAmt) external payable {
    require(tknAmt == msg.value, "unmatched-amount");
    insuranceAmt = add(insuranceAmt, tknAmt);
    emit LogAddInsurance(tknAmt);
  }

  /**
    * @dev Withdraw Insurance from the pool.
    * @notice only master can call this function.
    * @param tknAmt insurance token amount to remove
  */
  function withdrawInsurance(uint tknAmt) external {
    require(msg.sender == instaIndex.master(), "not-master");
    require(tknAmt <= insuranceAmt, "not-enough-insurance");
    msg.sender.transfer(tknAmt);
    insuranceAmt = sub(insuranceAmt, tknAmt);
    emit LogWithdrawInsurance(tknAmt);
  }

  /**
    * @dev Shut the pool.
    * @notice only master can call this function.
  */
  function shutdown() external {
    require(msg.sender == instaIndex.master(), "not-master");
    paused() ? _unpause() : _pause();
  }

  receive() external payable {}
}
