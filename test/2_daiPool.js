const { BN, ether, balance } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const RegistryContract = artifacts.require("Registry");
const PoolTokenContract = artifacts.require("PoolToken");
const PoolETHContract = artifacts.require("PoolETH");

const DaiRateLogic = artifacts.require("DaiRateLogic");
const EthRateLogic = artifacts.require("EthRateLogic");


const masterAddr = "0xfCD22438AD6eD564a1C26151Df73F6B33B817B56"

// ABI
const daiABI = require('./abi/erc20');

const userAddress = '0x9eb7f2591ed42dee9315b6e2aaf21ba85ea69f8c';
const daiAddress = '0x6b175474e89094c44da98b954eedeac495271d0f';
const daiContract = new web3.eth.Contract(daiABI, daiAddress);

contract('DAI Pool', async accounts => {
  let ethAddr = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
    let daiAddr = "0x6b175474e89094c44da98b954eedeac495271d0f";

    let defaultAddr = "0x0000000000000000000000000000000000000000";

    
    let ethPoolInstance;
    let daiPoolInstance;
    let registryInstance;

    let ethRateLogicInstance;
    let daiRateLogicInstance;
    before(async() => {
        registryInstance = await RegistryContract.deployed();
        ethPoolInstance = await PoolETHContract.deployed();
        daiPoolInstance = await PoolTokenContract.deployed();

        ethRateLogicInstance = await EthRateLogic.deployed();
        daiRateLogicInstance = await DaiRateLogic.deployed();
    })

  it('should send ether to the user address', async () => {
    // Send 1 eth to userAddress to have gas to send an ERC20 tx.
    await web3.eth.sendTransaction({
      from: accounts[0],
      to: userAddress,
      value: ether('1')
    });
    const ethBalance = await balance.current(userAddress);
    expect(new BN(ethBalance)).to.be.bignumber.least(new BN(ether('1')));
  });

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

  it('should send DAI to the account[0] address', async () => {
    await daiContract.methods
      .transfer(accounts[0], ether('1000').toString())
      .send({ from: userAddress});
    const daiBalance = await daiContract.methods.balanceOf(accounts[0]).call();
    expect(new BN(daiBalance)).to.be.bignumber.least(ether('1000'));
  });

  it('should add DAI pool in registry', async () => {
    await addPool(registryInstance, daiPoolInstance.address, daiAddr);
  });

  it('should enable DAI pool in registry', async () => {
      await enablePool(registryInstance, daiPoolInstance.address);
  });

  it('should update DAI Logic contract in registry', async () => {
      await updateRateLogic(registryInstance, daiPoolInstance.address, daiRateLogicInstance.address);
  });

  it('should give DAI allowance for DAI pool', async () => {
    await daiContract.methods
      .approve(daiPoolInstance.address, ether('1000').toString())
      .send({ from: userAddress});
    const daiBalance = await daiContract.methods.allowance(userAddress, daiPoolInstance.address).call();
    expect(new BN(daiBalance)).to.be.bignumber.least(ether('1000'));
  });

  it('should deposit 100 DAI in DAI pool', async () => {
    var amountInWei = (ether("100")).toString()
    await daiPoolInstance.deposit(amountInWei, {from: userAddress});
    const daiBalance = await daiContract.methods.balanceOf(daiPoolInstance.address).call();
    expect(new BN(daiBalance)).to.be.bignumber.least(amountInWei);
    var totalSupply = await daiPoolInstance.totalSupply();
    expect(new BN(totalSupply)).to.be.bignumber.least(amountInWei);
  });

  it('should add profit 10 DAI and calculate exchange rate', async () => {
    var amountInWei = new BN(ether("10")).toString()
    await daiContract.methods
    .transfer(daiRateLogicInstance.address, amountInWei)
    .send({ from: userAddress});
    var exchangeRateInit =  await daiPoolInstance.exchangeRate()
    await daiPoolInstance.setExchangeRate({from: masterAddr});
    var exchangeRateFinal =  await daiPoolInstance.exchangeRate()
    expect(exchangeRateInit).to.not.equal(exchangeRateFinal);
  });

  it('should give DAI allowance for DAI pool(accounts[0])', async () => {
    await daiContract.methods
      .approve(daiPoolInstance.address, ether('1000').toString())
      .send({ from: accounts[0]});
    const daiBalance = await daiContract.methods.allowance(accounts[0], daiPoolInstance.address).call();
    expect(new BN(daiBalance)).to.be.bignumber.least(ether('1000'));
  });

  it('should deposit 100 DAI in DAI pool(accounts[0])', async () => {
    var amountInWei = (ether("100")).toString()
    await daiPoolInstance.deposit(amountInWei, {from: accounts[0]});
    const wrapDaiBalance = await daiPoolInstance.balanceOf(accounts[0])
    expect(new BN(wrapDaiBalance)).to.be.bignumber.least((ether("90")).toString());
  });

  it('should withdraw 10 DAI in DAI pool', async () => {
    var amountInWei = (ether("10")).toString()
    await daiPoolInstance.withdraw(amountInWei, accounts[1], {from: userAddress});
    const daiBalance = await daiContract.methods.balanceOf(accounts[1]).call();
    expect(new BN(daiBalance)).to.be.bignumber.least(amountInWei);
  });

  it('should withdraw total DAI in DAI pool', async () => {
    var amountInWei = (ether("1000")).toString()
    var checkAmt = (ether("90")).toString()
    await daiPoolInstance.withdraw(amountInWei, accounts[2], {from: userAddress});
    const daiBalance = await daiContract.methods.balanceOf(accounts[3]).call();
    expect(new BN(daiBalance)).to.be.bignumber.least(checkAmt);
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

async function updateRateLogic(registryInstance, poolAddr, logicAddr) {
  await registryInstance.updatePoolLogic(poolAddr, logicAddr, {from: masterAddr});

  var _logicAddr = await registryInstance.poolLogic(poolAddr);
  expect(_logicAddr).to.equal(logicAddr);
}