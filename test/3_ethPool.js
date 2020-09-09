const { BN, ether, balance } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const RegistryContract = artifacts.require("Registry");
const PoolETHContract = artifacts.require("PoolETH");

const FlusherLogic = artifacts.require("FlusherLogic");
const SettleLogic = artifacts.require("SettleLogic");
const EthRateLogic = artifacts.require("EthRateLogic");


const masterAddr = "0xfCD22438AD6eD564a1C26151Df73F6B33B817B56"

// ABI

contract('ETH Pool', async accounts => {
    let ethAddr = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

    let accountA = accounts[0];
    let accountB = accounts[1];

    let ethPoolInstance;
    let registryInstance;

    let ethRateLogicInstance;
    let flusherLogicInstance;
    let settleLogicInstance;
    before(async() => {
        registryInstance = await RegistryContract.deployed();
        ethPoolInstance = await PoolETHContract.deployed();

        ethRateLogicInstance = await EthRateLogic.deployed();
        flusherLogicInstance = await FlusherLogic.deployed();
        settleLogicInstance = await SettleLogic.deployed();
    })

  it('should send ether to the master address', async () => {
    // Send 1 eth to userAddress to have gas to send an ERC20 tx.
    await web3.eth.sendTransaction({
      from: accounts[0],
      to: masterAddr,
      value: ether('1')
    });
    const ethBalance = await balance.current(masterAddr);
    expect(new BN(ethBalance)).to.be.bignumber.least(new BN(ether('1')));
  });

  it('should add ETH pool in registry', async () => {
    await addPool(registryInstance, ethPoolInstance.address, ethAddr);
  });

  it('should update ETH Logic contract in registry', async () => {
      await updateRateLogic(registryInstance, ethPoolInstance.address, ethAddr, ethRateLogicInstance.address);
  });

  it('should update Flusher Logic contract in registry for ETH POOL', async () => {
    await updateFlusherLogic(registryInstance, ethPoolInstance.address, ethAddr, flusherLogicInstance.address);
  });

  it('should update Settle Logic contract in registry for ETH POOL', async () => {
    await updateSettleLogic(registryInstance, ethPoolInstance.address, ethAddr, settleLogicInstance.address);
  });

  it('should update Pool Cap in registry for ETH POOL', async () => {
    var amountInWei = (ether("100000000")).toString()
    await updatePoolCap(registryInstance, ethPoolInstance.address, ethAddr, amountInWei);
  });

  it('should deposit 5 ETH in ETH pool', async () => {
    var amountInWei = (ether("5")).toString()
    await ethPoolInstance.deposit(amountInWei, {from: accountA, value: amountInWei});
    const ethBalance = await web3.eth.getBalance(ethPoolInstance.address);
    expect(new BN(ethBalance)).to.be.bignumber.least(amountInWei);
    var totalSupply = await ethPoolInstance.totalSupply();
    expect(new BN(totalSupply)).to.be.bignumber.least(amountInWei);
  });

  it('should add profit 0.5 ETH and calculate exchange rate', async () => {
    var amountInWei = new BN(ether("0.5")).toString()
    await web3.eth.sendTransaction({
        from: accountA,
        to: ethRateLogicInstance.address,
        value: amountInWei
      });
    var exchangeRateInit =  await ethPoolInstance.exchangeRate()
    await updateExchangeLogic(ethPoolInstance, settleLogicInstance.address);
    var exchangeRateFinal =  await ethPoolInstance.exchangeRate()
    expect(exchangeRateInit).to.not.equal(exchangeRateFinal);
  });

  it('should deposit 5 ETH in ETH pool(accountB)', async () => {
    var amountInWei = (ether("5")).toString()
    await ethPoolInstance.deposit(amountInWei, {from: accountB, value: amountInWei});
    const wrapETHBalance = await ethPoolInstance.balanceOf(accountB)
    expect(new BN(wrapETHBalance)).to.be.bignumber.least((ether("4")).toString());
  });

  it('should withdraw 0.5 ETH in ETH pool', async () => {
    var amountInWei = (ether("0.5")).toString()
    await ethPoolInstance.withdraw(amountInWei, accounts[2], {from: accountA});
    const ethBalance = await web3.eth.getBalance(accounts[2]);
    expect(new BN(ethBalance)).to.be.bignumber.least(amountInWei);
  });

  it('should withdraw total ETH in ETH pool', async () => {
    var amountInWei = (ether("1000")).toString()
    var checkAmt = (ether("4.5")).toString()
    await ethPoolInstance.withdraw(amountInWei, accounts[3], {from: accountA});
    const ethBalance = await web3.eth.getBalance(accounts[3]);
    expect(new BN(ethBalance)).to.be.bignumber.least(checkAmt);
  });
});


async function addPool(registryInstance, poolAddr, tokenAddr) {
  await registryInstance.addPool(tokenAddr, poolAddr, {from: masterAddr});
  
  var _poolAddr = await registryInstance.poolToken(tokenAddr);
  expect(_poolAddr).to.equal(poolAddr);
}

async function enablePool(registryInstance, poolAddr) {
 await registryInstance.updatePool(poolAddr, {from: masterAddr});
 
 var _isPool = await registryInstance.isPool(poolAddr);
 expect(_isPool).to.equal(true);
}

async function updateRateLogic(registryInstance, poolAddr, tokenAddr, logicAddr) {
  await registryInstance.updatePoolLogic(tokenAddr, logicAddr, {from: masterAddr});

  var _logicAddr = await registryInstance.poolLogic(poolAddr);
  expect(_logicAddr).to.equal(logicAddr);
}

async function updatePoolCap(registryInstance, poolAddr, tokenAddr, capAmt) {
  await registryInstance.updateCap(tokenAddr, capAmt, {from: masterAddr});

  var _capAmt = await registryInstance.poolCap(poolAddr);
  expect(new BN(_capAmt)).to.bignumber.equal(capAmt);
}

async function updateFlusherLogic(registryInstance, poolAddr, tokenAddr, flusherLogic) {
  await registryInstance.updateFlusherLogic(tokenAddr, flusherLogic, {from: masterAddr});

  var _logicAddr = await registryInstance.flusherLogic(poolAddr);
  expect(_logicAddr).to.equal(flusherLogic);
}

async function updateSettleLogic(registryInstance, poolAddr, tokenAddr, settleLogic) {
  await registryInstance.addSettleLogic(tokenAddr, settleLogic, {from: masterAddr});

  var _isSettleLogic = await registryInstance.settleLogic(poolAddr, settleLogic);
  expect(_isSettleLogic).to.equal(true);
}

async function updateExchangeLogic(ethPoolInstance, settleLogic) {
  var abi = {
        "inputs": [
          {
            "internalType": "address",
            "name": "pool",
            "type": "address"
          }
        ],
        "name": "calculateExchangeRate",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
  }
  var encodeCalldata = web3.eth.abi.encodeFunctionCall(abi, [ethPoolInstance.address]);
  await ethPoolInstance.settle([settleLogic], [encodeCalldata], {from: masterAddr});
}