const PoolToken = artifacts.require("PoolToken");
const DaiRateLogic = artifacts.require("DaiRateLogic");
const Registry = artifacts.require("Registry");

module.exports = async function(deployer, networks, accounts) {
    var DAI_Addr = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
    var registryInstance = await Registry.deployed();
    var daiPoolInstance = await deployer.deploy(PoolToken, registryInstance.address, "Insta DAI", "IDAI", DAI_Addr);
    var daiRateInstance = await deployer.deploy(DaiRateLogic, daiPoolInstance.address, DAI_Addr);
};