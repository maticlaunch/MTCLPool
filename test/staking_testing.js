const MTCLStaking = artifacts.require("MTCLStaking");
const TestMaticLaunchToken = artifacts.require("TestMaticLaunchToken");
const MTCLInfo = artifacts.require("MTCLInfo");
const truffleAssert = require('truffle-assertions');
const chai = require('chai');
const { expect } = require('chai');
const BN = require('bn.js');

// Enable and inject BN dependency
chai.use(require('chai-bn')(BN));

contract('MTCLStaking', (accounts) => {
    let stakeContract;
    let token;
    let info;
    before('should setup the contract instance', async () => {
        token = await TestMaticLaunchToken.deployed();
        info = await MTCLInfo.deployed();
        stakeContract = await MTCLStaking.deployed();
        // console.log(stake.address)
    });

    it("min stake test", async () => {
        let oldBalance = await token.balanceOf(accounts[0])
        await token.approve(stakeContract.address, oldBalance.toString())
        await truffleAssert.reverts(stakeContract.stake("10", { from: accounts[0]}));
        
    })

    it("stake test", async () => {
        let oldBalance = await token.balanceOf(accounts[0])
        await token.approve(stakeContract.address, oldBalance.toString())
        // console.log(new BN(balance).toString())
        await stakeContract.stake(oldBalance, { from: accounts[0]});
        // let newBalance = await token.balanceOf(accounts[0]);
        
    })

    it("unstake test before time should not work", async () => {
        let stakeDetails = await stakeContract.stakerInfos(accounts[0]);
        await truffleAssert.reverts(stakeContract.unstake(stakeDetails.balance.toString(), "0"))
    })

    it("unstake test after time should work", async () => {
        await info.setMinUnstakeTime("0")
        let stakeDetails = await stakeContract.stakerInfos(accounts[0]);
        await stakeContract.unstake(stakeDetails.balance.toString(), "0")
    })

    // it("unstake retain min value", async () => {
    //     let balance = await token.balanceOf(accounts[0])
    //     await token.approve(stakeContract.address, balance.toString())
    //     await stakeContract.stake(balance, { from: accounts[0]});
    //     let stakeDetails = await stakeContract.stakerInfos(accounts[0]);
    //     await info.setMinInvestorMTCLBalance(balance.sub(new BN('1')).toString());
    //     await truffleAssert.reverts(stakeContract.unstake(stakeDetails.balance.sub(new BN("1")).toString(), "0"))
    // })

    // it("unstake should work in full", async () => {
    //     let stakeDetails = await stakeContract.stakerInfos(accounts[0]);
    //     await stakeContract.unstake(stakeDetails.balance.toString(), "0")
    // })

    it("unstake should work partially", async () => {
        let balance = await token.balanceOf(accounts[0])
        await token.approve(stakeContract.address, balance.toString())
        await stakeContract.stake(balance, { from: accounts[0]});
        let stakeDetails = await stakeContract.stakerInfos(accounts[0]);
        await info.setMinInvestorMTCLBalance(balance.sub(new BN("2000000000000000000")));
        await stakeContract.unstake("2000000000000000000", "0")
    })

    it("unstake should burn token", async () => {
        let balance = await token.balanceOf(accounts[0])
        await token.approve(stakeContract.address, balance.toString())
        await stakeContract.stake(balance, { from: accounts[0]});
        let stakeDetails = await stakeContract.stakerInfos(accounts[0]);
        await stakeContract.unstake(stakeDetails.balance.toString(), "10")
        let deadBalance = (await token.balanceOf("0x000000000000000000000000000000000000dEaD")).toString()
        assert.equal(stakeDetails.balance.mul(new BN('10')).div(new BN('100')).toString(), deadBalance.toString())
    })

})

