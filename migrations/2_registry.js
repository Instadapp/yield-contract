const Registry = artifacts.require("Registry");
module.exports = async function(deployer, networks, accounts) {
    await deployer.deploy(Registry, accounts[0]); //deploy registry.sol contract
};