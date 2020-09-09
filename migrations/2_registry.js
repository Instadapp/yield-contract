const Registry = artifacts.require("Registry");
const FlusherLogic = artifacts.require("FlusherLogic");
const SettleLogic = artifacts.require("SettleLogic");
module.exports = async function(deployer, networks, accounts) {
    await deployer.deploy(Registry, accounts[0]); //deploy registry.sol contract
    await deployer.deploy(FlusherLogic, accounts[0]); //deploy flusherLogic.sol contract
    await deployer.deploy(SettleLogic, accounts[0]); //deploy settleLogic.sol contract
};