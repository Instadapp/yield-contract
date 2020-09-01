const { BN, ether, balance } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const RegistryContract = artifacts.require("Registry");
const PoolTokenContract = artifacts.require("PoolToken");
const PoolETHContract = artifacts.require("PoolETH");

const DaiRateLogic = artifacts.require("DaiRateLogic");
const EthRateLogic = artifacts.require("EthRateLogic");


const masterAddr = "0xfCD22438AD6eD564a1C26151Df73F6B33B817B56"

contract('Registry.sol', async accounts => {
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
    

    it('should send ether to the Master address', async () => {
        await web3.eth.sendTransaction({
        from: accounts[0],
        to: masterAddr,
        value: ether('10')
        });
        const ethBalance = await balance.current(masterAddr);
        expect(new BN(ethBalance)).to.be.bignumber.least(new BN(ether('10')));
    });

    it('should add ETH pool in registry', async () => {
        await addPool(registryInstance, ethPoolInstance.address, ethAddr);
    });

    it('should enable ETH pool in registry', async () => {
        await enablePool(registryInstance, ethPoolInstance.address);
    });

    it('should remove ETH pool in registry', async () => {
        await removePool(registryInstance, ethAddr);
    });

    it('should disable ETH pool in registry', async () => {
        await disablePool(registryInstance, ethPoolInstance.address);
    });

    it('should add ETH pool in registry', async () => {
        await addPool(registryInstance, ethPoolInstance.address, ethAddr);
    });

    it('should enable ETH pool in registry', async () => {
        await enablePool(registryInstance, ethPoolInstance.address);
    });

    it('should add DAI pool in registry', async () => {
        await addPool(registryInstance, daiPoolInstance.address, daiAddr);
    });

    it('should enable DAI pool in registry', async () => {
        await enablePool(registryInstance, daiPoolInstance.address);
    });

    it('should update ETH Logic contract in registry', async () => {
        await updateRateLogic(registryInstance, ethPoolInstance.address, ethRateLogicInstance.address);
    });

    it('should update DAI Logic contract in registry', async () => {
        await updateRateLogic(registryInstance, daiPoolInstance.address, daiRateLogicInstance.address);
    });
});

async function addPool(registryInstance, poolAddr, tokenAddr) {
    await registryInstance.addPool(tokenAddr, poolAddr, {from: masterAddr});
    
    var _poolAddr = await registryInstance.poolToken(tokenAddr);
    expect(_poolAddr).to.equal(poolAddr);
}

async function removePool(registryInstance, tokenAddr) {
    await registryInstance.removePool(tokenAddr, {from: masterAddr});
    
    var _poolAddr = await registryInstance.poolToken(tokenAddr);
    expect(_poolAddr).to.equal("0x0000000000000000000000000000000000000000");
}


async function enablePool(registryInstance, poolAddr) {
   await registryInstance.updatePool(poolAddr, {from: masterAddr});
   
   var _isPool = await registryInstance.isPool(poolAddr);
   expect(_isPool).to.equal(true);
}

async function disablePool(registryInstance, poolAddr) {
    await registryInstance.updatePool(poolAddr, {from: masterAddr});
    
    var _isPool = await registryInstance.isPool(poolAddr);
    expect(_isPool).to.equal(false);
 }

async function updateRateLogic(registryInstance, poolAddr, logicAddr) {
    await registryInstance.updatePoolLogic(poolAddr, logicAddr, {from: masterAddr});

    var _logicAddr = await registryInstance.poolLogic(poolAddr);
    expect(_logicAddr).to.equal(logicAddr);
}