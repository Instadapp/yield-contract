pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

interface YieldPool {
  function balanceOf(address) external view returns (uint);
  function deposit(uint) external payable returns (uint);
  function withdraw(uint, address) external returns (uint);
}

interface RegistryInterface {
  function signer(address) external view returns (bool);
  function chief(address) external view returns (bool);
  function poolToken(address) external view returns (address);
}

contract Flusher {
  using SafeERC20 for IERC20;

  address payable public owner;
  RegistryInterface public constant registry = RegistryInterface(address(0)); // TODO - Change while deploying.
  bool public shield;
  uint256 public shieldBlockTime;
  uint256 internal waitBlockTime = 518400; // 90 days blocktime.

  modifier isSigner {
    require(registry.signer(msg.sender), "not-signer");
    _;
  }

  modifier isChief {
    require(registry.chief(msg.sender), "not-chief");
    _;
  }

  event LogInit(address indexed owner);
  event LogSwitch(bool indexed boooool);

  event LogDeposit(
    address indexed caller,
    address indexed token,
    address indexed tokenPool,
    uint amount
  );

  event LogWithdraw(
    address indexed caller,
    address indexed token,
    address indexed tokenPool,
    uint amount
  );

  event LogWithdrawToOwner(
    address indexed caller,
    address indexed token,
    address indexed owner,
    uint amount
  );

  function deposit(address token) public isSigner {
    require(address(token) != address(0), "invalid-token");

    address poolToken = registry.poolToken(token);
    IERC20 tokenContract = IERC20(token);
    
    if (poolToken != address(0)) {
      YieldPool poolContract = YieldPool(poolToken);
      uint amt;
      if (address(tokenContract) == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
        amt = address(this).balance;
        poolContract.deposit{value: amt}(amt);
      } else {
        amt = tokenContract.balanceOf(address(this));
        if (tokenContract.allowance(address(this), address(poolContract)) == 0)
          tokenContract.approve(address(poolContract), uint(-1));

        poolContract.deposit(amt);
      }
      emit LogDeposit(msg.sender, token, address(poolContract), amt);
    } else {
      uint amt = tokenContract.balanceOf(address(this));
      tokenContract.safeTransfer(owner, amt);
      emit LogWithdrawToOwner(msg.sender, token, owner, amt);
    }
  }

  function withdraw(address token, uint amount) external isSigner returns (uint _amount) {
    require(address(token) != address(0), "invalid-token");
    address poolToken = registry.poolToken(token);
    require(poolToken != address(0), "invalid-pool");
    
    _amount = YieldPool(poolToken).withdraw(amount, owner);
    emit LogWithdraw(msg.sender, token, poolToken, _amount);
  }

  /**
   * @dev withdraw to owner (rare case)
   */
  function claim(address token) external isSigner returns (uint) {
    require(address(token) != address(0), "invalid-token");
    
    uint amount;
    if (address(token) == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
      amount = address(this).balance;
      payable(owner).transfer(amount);
    } else {
      IERC20 tokenContract = IERC20(token);
      amount = tokenContract.balanceOf(address(this));
      tokenContract.safeTransfer(address(owner), amount);
    }
    emit LogWithdrawToOwner(msg.sender, token, owner, amount);
  }

  function setBasic(address newOwner, address token) external {
    require(owner == address(0), "already-an-owner");
    owner = payable(newOwner);
    deposit(token);
    emit LogInit(newOwner);
  }

  function switchShield() external isChief {
    require(registry.chief(msg.sender), "not-chief");
    shield = !shield;
    if (!shield) {
      shieldBlockTime = block.number + waitBlockTime;
    } else {
      delete shieldBlockTime;
    }
    emit LogSwitch(shield);
  }

  /**
   * @dev backdoor function
   */
  function spell(address _target, bytes calldata _data) external isChief {
    require(!shield, "shield-access-denied");
    require(shieldBlockTime != 0 && shieldBlockTime <= block.number, "less-than-ninty-days");
    require(_target != address(0), "target-invalid");
    require(_data.length > 0, "data-invalid");
    bytes memory _callData = _data;
    address _owner = owner;
    assembly {
      let succeeded := delegatecall(gas(), _target, add(_callData, 0x20), mload(_callData), 0, 0)
      switch iszero(succeeded)
      case 1 {
        // throw if delegatecall failed
        let size := returndatasize()
        returndatacopy(0x00, 0x00, size)
        revert(0x00, size)
      }
    }
    require(_owner == owner, "owner-change-denied");
  }

}