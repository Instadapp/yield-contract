const PoolETH = artifacts.require("PoolETH");
const Registry = artifacts.require("Registry");
const EthRateLogic = artifacts.require("EthRateLogic");


module.exports = async function(deployer, networks, accounts) {
    var ETH_Addr = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
    var registryInstance = await Registry.deployed();
    var ethPoolInstance = await deployer.deploy(PoolETH, registryInstance.address, "Insta ETH", "IETH", ETH_Addr);
    var ethRateInstance = await deployer.deploy(EthRateLogic, ethPoolInstance.address);
};