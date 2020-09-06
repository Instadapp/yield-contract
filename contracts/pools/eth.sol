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
  function fee(address) external view returns (uint);
  function withdrawalFee(address) external view returns (uint);
  function isDsa(address, address) external view returns (bool);
  function checkSettleLogics(address, address[] calldata) external view returns (bool);
}

interface RateInterface {
  function getTotalToken() external returns (uint totalUnderlyingTkn);
}

contract PoolETH is ReentrancyGuard, ERC20Pausable, DSMath {
  using SafeERC20 for IERC20;

  event LogDeploy(address indexed dsa, address indexed token, uint amount);
  event LogExchangeRate(uint exchangeRate, uint tokenBalance, uint insuranceAmt);
  event LogSettle(uint settleBlock);
  event LogDeposit(address indexed user, uint depositAmt, uint poolMintAmt);
  event LogWithdraw(address indexed user, uint withdrawAmt, uint poolBurnAmt, uint feeAmt);
  event LogAddFee(uint amount);
  event LogWithdrawFee(uint amount);
  event LogPausePool(bool);

  IERC20 public immutable baseToken; // Base token.
  RegistryInterface public immutable registry; // Pool Registry
  IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723);

  uint private tokenBalance; // total token balance
  uint public exchangeRate = 10 ** 18; // initial 1 token = 1
  uint public feeAmt; // fee collected on profits

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
    _totalToken = sub(_totalToken, feeAmt);
    uint _currentRate = getCurrentRate(_totalToken);
    require(_currentRate != 0, "current-rate-is-zero");
    if (_currentRate > _previousRate) { // loss => deduct partially/fully from insurance amount
        _currentRate = _previousRate;
    } else { // profit => add to insurance amount
      uint _newFee = wmul(sub(_totalToken, tokenBalance), registry.fee(address(this)));
      feeAmt = add(feeAmt, _newFee);
      tokenBalance = sub(_totalToken, _newFee);
      _currentRate = getCurrentRate(tokenBalance);
    }
    exchangeRate = _currentRate;
    emit LogExchangeRate(exchangeRate, tokenBalance, feeAmt);
  }

  /**
    * @dev Delegate the calls to Connector And this function is ran by cast().
    * @param _target Target to of Connector.
    * @param _data CallData of function in Connector.
  */
  function spell(address _target, bytes memory _data) internal {
    require(_target != address(0), "target-invalid");
    assembly {
      let succeeded := delegatecall(gas(), _target, add(_data, 0x20), mload(_data), 0, 0)

      switch iszero(succeeded)
        case 1 {
          // throw if delegatecall failed
          let size := returndatasize()
          returndatacopy(0x00, 0x00, size)
          revert(0x00, size)
        }
    }
  }

  /**
    * @dev Settle the assets on dsa and update exchange rate
    * @param _targets array of connector's address
    * @param _data array of connector's function calldata
  */
  function settle(address[] calldata _targets, bytes[] calldata _data) external isChief {
    require(_targets.length == _data.length , "array-length-invalid");
    require(registry.checkSettleLogics(address(this), _targets), "not-logic");
    for (uint i = 0; i < _targets.length; i++) {
      spell(_targets[i], _data[i]);
    }
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
    require(_tknAmt <= poolBal, "not-enough-liquidity-available");

    tokenBalance = sub(tokenBalance, _tknAmt);

    _burn(msg.sender, _burnAmt);

    uint _withdrawalFee = registry.withdrawalFee(address(this));
    uint _feeAmt;
    if (_withdrawalFee > 0) {
      _feeAmt = wmul(_tknAmt, _withdrawalFee);
      feeAmt = add(feeAmt, _feeAmt);
      _tknAmt = sub(_tknAmt, _feeAmt);
    }

    payable(to).transfer(_tknAmt);

    emit LogWithdraw(msg.sender, _tknAmt, _burnAmt, _feeAmt);
  }

  /**
    * @dev Add Insurance to the pool.
    * @param tknAmt insurance token amount to add
  */
  function addFee(uint tknAmt) external payable {
    require(tknAmt == msg.value, "unmatched-amount");
    feeAmt = add(feeAmt, tknAmt);
    emit LogAddFee(tknAmt);
  }

  /**
    * @dev Withdraw Insurance from the pool.
    * @notice only master can call this function.
    * @param tknAmt insurance token amount to remove
  */
  function withdrawFee(uint tknAmt) external {
    require(msg.sender == instaIndex.master(), "not-master");
    require(tknAmt <= feeAmt, "not-enough-insurance");
    msg.sender.transfer(tknAmt);
    feeAmt = sub(feeAmt, tknAmt);
    emit LogWithdrawFee(tknAmt);
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
