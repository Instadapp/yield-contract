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

  it('should give DAI allowance for DAI pool', async () => {
    await daiContract.methods
      .approve(daiPoolInstance.address, ether('1000').toString())
      .send({ from: userAddress});
    const daiBalance = await daiContract.methods.allowance(userAddress, daiPoolInstance.address).call();
    expect(new BN(daiBalance)).to.be.bignumber.least(ether('1000'));
  });

  it('should deposit 100 DAI in DAI pool', async () => {
    var amountInWei = new BN(ether(100)).toString()
    await daiPoolInstance.deposit(amountInWei, {from: userAddress});
    const daiBalance = await daiContract.methods.balanceOf(daiPoolInstance.address).call();
    expect(new BN(daiBalance)).to.be.bignumber.least(amountInWei);
    var totalSupply = await poolInstance.totalSupply();
    expect(new BN(totalSupply)).to.be.bignumber.least(amountInWei);
  });

  it('should add profit 10 DAI and calculate exchange rate', async () => {
    var amountInWei = new BN(ether(10)).toString()
    await daiContract.methods
    .transfer(daiRateLogicInstance.address, amountInWei)
    .send({ from: userAddress});
    await daiPoolInstance.deposit(amountInWei, {from: userAddress});
    const daiBalance = await daiContract.methods.balanceOf(daiPoolInstance.address).call();
    expect(new BN(daiBalance)).to.be.bignumber.least(amountInWei);
    var totalSupply = await poolInstance.totalSupply();
    expect(new BN(totalSupply)).to.be.bignumber.least(amountInWei);
  });
});