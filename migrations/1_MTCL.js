const MTCLInfo = artifacts.require("MTCLInfo");
const MTCLStaking = artifacts.require("MTCLStaking");
const MTCLFactory = artifacts.require("MTCLFactory");

const TestMaticLaunchToken = artifacts.require("TestMaticLaunchToken");
const TestUSDTToken = artifacts.require("TestUSDTToken");
const TestSaleToken = artifacts.require("TestSaleToken");

module.exports = async function (deployer) {
  await deployer.deploy(MTCLInfo);
  const info = await MTCLInfo.deployed();
  
  await deployer.deploy(TestMaticLaunchToken);
  const token = await TestMaticLaunchToken.deployed();

  await deployer.deploy(TestUSDTToken);
  const usdt = await TestUSDTToken.deployed();

  await deployer.deploy(TestSaleToken);
  const saleTkn = await TestSaleToken.deployed();

  await deployer.deploy(MTCLStaking, token.address, info.address);
  const staking = await MTCLStaking.deployed();
  
  await deployer.deploy(MTCLFactory, info.address, token.address, staking.address);
  const factory = await MTCLFactory.deployed();
  
};
