// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { DSMath } from "../libs/safeMath.sol";

interface IndexInterface {
  function master() external view returns (address);
  function build(address _owner, uint accountVersion, address _origin) external returns (address _account);
}

interface RegistryInterface {
  function chief(address) external view returns (bool);
  function poolLogic(address) external returns (address);
  function fee(address) external view returns (uint);
  function poolCap(address) external view returns (uint);
  function checkSettleLogics(address, address[] calldata) external view returns (bool);
}

interface RateInterface {
  function getTotalToken() external returns (uint totalUnderlyingTkn);
}

contract PoolToken is ReentrancyGuard, DSMath, ERC20Pausable {
  using SafeERC20 for IERC20;

  event LogDeploy(address indexed dsa, address token, uint amount);
  event LogExchangeRate(uint exchangeRate, uint tokenBalance, uint insuranceAmt);
  event LogSettle(uint settleBlock);
  event LogDeposit(address indexed user, uint depositAmt, uint poolMintAmt);
  event LogWithdraw(address indexed user, uint withdrawAmt, uint poolBurnAmt);
  event LogAddFee(uint amount);
  event LogWithdrawFee(uint amount);
  event LogPausePool(bool);

  IERC20 public immutable baseToken; // Base token. Eg:- DAI, USDC, etc.
  RegistryInterface public immutable registry; // Pool Registry
  IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723); // Main Index

  uint public exchangeRate; // initial 1 token = 1
  uint public feeAmt; // fee collected on profits

  constructor(
      address _registry,
      string memory _name,
      string memory _symbol,
      address _baseToken
  ) public ERC20(_name, _symbol) {
      baseToken = IERC20(_baseToken);
      registry = RegistryInterface(_registry);
      exchangeRate = 10 ** uint(36 - ERC20(_baseToken).decimals());
  }

  modifier isChief() {
      require(registry.chief(msg.sender) || msg.sender == instaIndex.master(), "not-chief");
      _;
  }

  /**
    * @dev get pool token rate
    * @param tokenAmt total token amount
    */
  function getCurrentRate(uint tokenAmt) internal view returns (uint) {
    return wdiv(totalSupply(), tokenAmt);
  }

  /**
    * @dev sets exchange rates
    */
  function setExchangeRate() public {
    require(msg.sender == address(this), "not-pool-address");
    uint _previousRate = exchangeRate;
    uint _totalToken = RateInterface(registry.poolLogic(address(this))).getTotalToken();
    _totalToken = sub(_totalToken, feeAmt);
    uint _currentRate = getCurrentRate(_totalToken);
    uint _tokenBal;
    require(_currentRate != 0, "current-rate-is-zero");
    if (_currentRate > _previousRate) { // loss => deduct partially/fully from insurance amount
        _currentRate = _previousRate;
    } else { // profit => add to insurance amount
      uint _newFee = wmul(sub(_totalToken, _tokenBal), registry.fee(address(this)));
      feeAmt = add(feeAmt, _newFee);
      _tokenBal = sub(_totalToken, _newFee);
      _currentRate = getCurrentRate(_tokenBal);
    }
    exchangeRate = _currentRate;
    emit LogExchangeRate(exchangeRate, _tokenBal, feeAmt);
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
    emit LogSettle(block.number);
  }

  /**
    * @dev Deposit token.
    * @param tknAmt token amount
    * @return _mintAmt amount of wrap token minted
  */
  function deposit(uint tknAmt) external whenNotPaused payable returns (uint _mintAmt) {
    require(msg.value == 0, "non-eth-pool");
    uint _tokenBal = wdiv(totalSupply(), exchangeRate);
    uint _newTknBal = add(_tokenBal, tknAmt);
    require(_newTknBal < registry.poolCap(address(this)), "unmatched-amount");
    baseToken.safeTransferFrom(msg.sender, address(this), tknAmt);
    _mintAmt = wmul(tknAmt, exchangeRate);
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
    require(to != address(0), "to-address-not-vaild");
    uint _userBal = wdiv(balanceOf(msg.sender), exchangeRate);
    uint _burnAmt;
    if (tknAmt >= _userBal) {
      _burnAmt = balanceOf(msg.sender);
      _tknAmt = _userBal;
    } else {
      _burnAmt = wmul(tknAmt, exchangeRate);
      _tknAmt = tknAmt;
    }
    require(_tknAmt <= baseToken.balanceOf(address(this)), "not-enough-liquidity-available");

    _burn(msg.sender, _burnAmt);
    baseToken.safeTransfer(to, _tknAmt);

    emit LogWithdraw(msg.sender, _tknAmt, _burnAmt);
  }

  /**
    * @dev Withdraw Insurance from the pool.
    * @notice only master can call this function.
    * @param wdAmt insurance token amount to remove
  */
  function withdrawFee(uint wdAmt) external {
    require(msg.sender == instaIndex.master(), "not-master");
    if (wdAmt > feeAmt) wdAmt = feeAmt;
    baseToken.safeTransfer(msg.sender, wdAmt);
    feeAmt = sub(feeAmt, wdAmt);
    emit LogWithdrawFee(wdAmt);
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
