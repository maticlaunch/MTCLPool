const MTCLStaking = artifacts.require("MTCLStaking");
const MTCLInfo = artifacts.require("MTCLInfo");
const MTCLFactory = artifacts.require("MTCLFactory");
const TestMaticLaunchToken = artifacts.require("TestMaticLaunchToken");
const TestUSDTToken = artifacts.require("TestUSDTToken");
const TestSaleToken = artifacts.require("TestSaleToken");
const truffleAssert = require('truffle-assertions');
const { formatBytes32String } = require("@ethersproject/strings");
const chai = require('chai');
const { expect } = require('chai');
const BN = require('bn.js');

// Enable and inject BN dependency
chai.use(require('chai-bn')(BN));

contract('MTCLFactory', (accounts) => {
    let factoryContract;
    let stakeContract;
    let token;
    let info;
    let saleTkn;
    before('should setup the contract instance', async () => {
        token = await TestMaticLaunchToken.deployed();
        usdt = await TestUSDTToken.deployed();
        info = await MTCLInfo.deployed();
        saleTkn = await TestSaleToken.deployed();
        stakeContract = await MTCLStaking.deployed();
        factoryContract = await MTCLFactory.deployed();
        await info.setUSDT(usdt.address);
        await info.setMTCLFactoryAddress(factoryContract.address);
    });

    it("min stake required to created pool", async () => {
        let saleTokenAddress = saleTkn.address
        let unsoleReciverAddress = accounts[1]
        let tokenPrice = "250000000000000000"
        let hardCap = "360000000000000000000000"
        let softCap = "150000000000000000000000"
        let maxInvest = "250000000000000000000"
        let minInvest = "150000000000000000000"
        let saleOpenTime = "1625747400"
        let saleCloseTime = "1627689599"
        let listingPrice = "300000000000000000"
        let lpAddTime = "1627775999"
        let lpLockDurationInDays = "365"
        let lpPercentAllocation = "15"
        let poolWithoutLiquidity = false
        let title = formatBytes32String("MaticLaunch | Test Pool 1")
        let userTelegram = formatBytes32String("maticlaunch")
        let userGithub = formatBytes32String("maticlaunch")
        let userTwitter = formatBytes32String("maticlaunch")
        let website = formatBytes32String("https://maticlaunch.org/")
        let logoLink = formatBytes32String("https://maticlaunch.org/")
        await truffleAssert.reverts(factoryContract.createPool([
            saleTokenAddress,
            unsoleReciverAddress,
            tokenPrice,
            hardCap,
            softCap,
            maxInvest,
            minInvest,
            saleOpenTime,
            saleCloseTime
        ], [
            listingPrice,
            lpAddTime,
            lpLockDurationInDays,
            lpPercentAllocation,
            poolWithoutLiquidity
        ], [
            title,
            userTelegram,
            userGithub,
            userTwitter,
            website,
            logoLink
        ]))
    });

    it("create pool should work", async () => {
        let oldBalance = await token.balanceOf(accounts[0])
        await token.approve(stakeContract.address, oldBalance.toString())
        await stakeContract.stake(oldBalance.div(new BN('2')), { from: accounts[0] });
        await saleTkn.approve(factoryContract.address, "200000000000000000000000000000000")
        let saleTokenAddress = saleTkn.address
        let unsoleReciverAddress = accounts[1]
        let tokenPrice = "250000000000000000"
        let hardCap = "360000000000000000000000"
        let softCap = "150000000000000000000000"
        let maxInvest = "250000000000000000000"
        let minInvest = "150000000000000000000"
        let saleOpenTime = "1625747400"
        let saleCloseTime = "1627689599"
        let listingPrice = "300000000000000000"
        let lpAddTime = "1627775999"
        let lpLockDurationInDays = "365"
        let lpPercentAllocation = "15"
        let poolWithoutLiquidity = false
        let title = formatBytes32String("MaticLaunch | Test Pool 1")
        let userTelegram = formatBytes32String("maticlaunch")
        let userGithub = formatBytes32String("maticlaunch")
        let userTwitter = formatBytes32String("maticlaunch")
        let website = formatBytes32String("https://maticlaunch.org/")
        let logoLink = formatBytes32String("https://maticlaunch.org/")
        await factoryContract.createPool([
            saleTokenAddress,
            unsoleReciverAddress,
            tokenPrice,
            hardCap,
            softCap,
            maxInvest,
            minInvest,
            saleOpenTime,
            saleCloseTime
        ], [
            listingPrice,
            lpAddTime,
            lpLockDurationInDays,
            lpPercentAllocation,
            poolWithoutLiquidity
        ], [
            title,
            userTelegram,
            userGithub,
            userTwitter,
            website,
            logoLink
        ])
    });

    it("create pool should not work without lp by other user", async () => {
        let oldBalance = await token.balanceOf(accounts[0])
        await token.transfer(accounts[1], oldBalance)
        await token.approve(stakeContract.address, oldBalance.toString(), { from: accounts[1] })
        await stakeContract.stake(oldBalance.div(new BN('2')), { from: accounts[1] });
        await saleTkn.approve(factoryContract.address, "200000000000000000000000000000000")
        let saleTokenAddress = saleTkn.address
        let unsoleReciverAddress = accounts[1]
        let tokenPrice = "250000000000000000"
        let hardCap = "360000000000000000000000"
        let softCap = "150000000000000000000000"
        let maxInvest = "250000000000000000000"
        let minInvest = "150000000000000000000"
        let saleOpenTime = "1625747400"
        let saleCloseTime = "1627689599"
        let listingPrice = "300000000000000000"
        let lpAddTime = "1627775999"
        let lpLockDurationInDays = "365"
        let lpPercentAllocation = "15"
        let poolWithoutLiquidity = true
        let title = formatBytes32String("MaticLaunch | Test Pool 1")
        let userTelegram = formatBytes32String("maticlaunch")
        let userGithub = formatBytes32String("maticlaunch")
        let userTwitter = formatBytes32String("maticlaunch")
        let website = formatBytes32String("https://maticlaunch.org/")
        let logoLink = formatBytes32String("https://maticlaunch.org/")
        await truffleAssert.reverts(factoryContract.createPool([
            saleTokenAddress,
            unsoleReciverAddress,
            tokenPrice,
            hardCap,
            softCap,
            maxInvest,
            minInvest,
            saleOpenTime,
            saleCloseTime
        ], [
            listingPrice,
            lpAddTime,
            lpLockDurationInDays,
            lpPercentAllocation,
            poolWithoutLiquidity
        ], [
            title,
            userTelegram,
            userGithub,
            userTwitter,
            website,
            logoLink
        ], { from: accounts[1] }))
    });

    it("create pool should work without lp by owner", async () => {
        await saleTkn.approve(factoryContract.address, "200000000000000000000000000000000")
        let saleTokenAddress = saleTkn.address
        let unsoleReciverAddress = accounts[1]
        let tokenPrice = "250000000000000000"
        let hardCap = "360000000000000000000000"
        let softCap = "150000000000000000000000"
        let maxInvest = "250000000000000000000"
        let minInvest = "150000000000000000000"
        let saleOpenTime = "1625747400"
        let saleCloseTime = "1627689599"
        let listingPrice = "300000000000000000"
        let lpAddTime = "1627775999"
        let lpLockDurationInDays = "365"
        let lpPercentAllocation = "15"
        let poolWithoutLiquidity = true
        let title = formatBytes32String("MaticLaunch | Test Pool 1")
        let userTelegram = formatBytes32String("maticlaunch")
        let userGithub = formatBytes32String("maticlaunch")
        let userTwitter = formatBytes32String("maticlaunch")
        let website = formatBytes32String("https://maticlaunch.org/")
        let logoLink = formatBytes32String("https://maticlaunch.org/")
        await factoryContract.createPool([
            saleTokenAddress,
            unsoleReciverAddress,
            tokenPrice,
            hardCap,
            softCap,
            maxInvest,
            minInvest,
            saleOpenTime,
            saleCloseTime
        ], [
            listingPrice,
            lpAddTime,
            lpLockDurationInDays,
            lpPercentAllocation,
            poolWithoutLiquidity
        ], [
            title,
            userTelegram,
            userGithub,
            userTwitter,
            website,
            logoLink
        ], { from: accounts[0] })
    });


})

