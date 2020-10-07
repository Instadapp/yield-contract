// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { DSMath } from "../libs/safeMath.sol";

interface IndexInterface {
  function master() external view returns (address);
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

contract PoolETH is ReentrancyGuard, ERC20Pausable, DSMath {

  event LogExchangeRate(uint exchangeRate, uint tokenBalance, uint insuranceAmt);
  event LogSettle(uint settleBlock);
  event LogDeposit(address indexed user, uint depositAmt, uint poolMintAmt);
  event LogWithdraw(address indexed user, uint withdrawAmt, uint poolBurnAmt);
  event LogWithdrawFee(uint amount);

  IERC20 public immutable baseToken; // Base token.
  RegistryInterface public immutable registry; // Pool Registry
  IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723);

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
    * @dev sets exchange rate
    */
  function setExchangeRate() public {
    require(msg.sender == address(this), "not-pool-address");
    uint _prevRate = exchangeRate;
    uint _totalToken = RateInterface(registry.poolLogic(address(this))).getTotalToken();
    _totalToken = sub(_totalToken, feeAmt);
    uint _newRate = wdiv(totalSupply(), _totalToken);
    require(_newRate != 0, "current-rate-is-zero");
    uint _tokenBal = wdiv(totalSupply(), _prevRate);
    if (_newRate > _prevRate) {
      _newRate = _prevRate;
    } else {
      uint _newFee = wmul(sub(_totalToken, _tokenBal), registry.fee(address(this)));
      feeAmt = add(feeAmt, _newFee);
      _tokenBal = sub(_totalToken, _newFee);
      _newRate = wdiv(totalSupply(), _tokenBal);
    }
    exchangeRate = _newRate;
    emit LogExchangeRate(exchangeRate, _tokenBal, feeAmt);
  }

  /**
    * @dev delegate the calls to connector and this function is ran by settle()
    * @param _target Target to of Connector.
    * @param _data CallData of function in Connector.
  */
  function spell(address _target, bytes memory _data) private {
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
    require(_targets.length != 0, "targets-length-zero");
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
    * @return mintAmt amount of wrap token minted
  */
  function deposit(uint tknAmt) external nonReentrant whenNotPaused payable returns (uint mintAmt) {
    require(tknAmt == msg.value, "unmatched-amount");
    uint _tokenBal = wdiv(totalSupply(), exchangeRate);
    uint _newTknBal = add(_tokenBal, tknAmt);
    require(_newTknBal < registry.poolCap(address(this)), "pool-cap-reached");
    mintAmt = wmul(msg.value, exchangeRate);
    _mint(msg.sender, mintAmt);
    emit LogDeposit(msg.sender, tknAmt, mintAmt);
  }

  /**
    * @dev Withdraw tokens.
    * @param tknAmt token amount
    * @param target withdraw tokens to address
    * @return wdAmt amount of token withdrawn
  */
  function withdraw(uint tknAmt, address target) external nonReentrant whenNotPaused returns (uint wdAmt) {
    require(target != address(0), "invalid-target-address");
    uint _userBal = wdiv(balanceOf(msg.sender), exchangeRate);
    uint _burnAmt;
    if (tknAmt >= _userBal) {
      _burnAmt = balanceOf(msg.sender);
      wdAmt = _userBal;
    } else {
      _burnAmt = wmul(tknAmt, exchangeRate);
      wdAmt = tknAmt;
    }
    require(wdAmt <= address(this).balance, "not-enough-liquidity-available");

    _burn(msg.sender, _burnAmt);
    payable(target).transfer(wdAmt);

    emit LogWithdraw(msg.sender, wdAmt, _burnAmt);
  }

  /**
    * @dev withdraw fee from the pool
    * @notice only master can call this function
    * @param wdAmt fee amount to withdraw
  */
  function withdrawFee(uint wdAmt) external {
    require(msg.sender == instaIndex.master(), "not-master");
    if (wdAmt > feeAmt) wdAmt = feeAmt;
    msg.sender.transfer(wdAmt);
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