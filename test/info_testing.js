const MTCLInfo = artifacts.require("MTCLInfo");
const truffleAssert = require('truffle-assertions');
const chai = require('chai');
const { expect } = require('chai');
const BN = require('bn.js');

// Enable and inject BN dependency
chai.use(require('chai-bn')(BN));

contract('MTCLInfo', (accounts) => {
    // it("should return the list of accounts", async () => {
    //     console.log(accounts);
    // });
    let info;
    before('should setup the contract instance', async () => {
        info = await MTCLInfo.deployed();
        
        console.log(info.address)
    });

    it("should work the dexRouter", async () => {
        let oldValue = '0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F';
        let newValue = '0x0F4F2Ac550A1b4e2280d04c21cEa7EBD822934b5';
        const oldContractValue = await info.getDexRouter()
        assert.equal(oldContractValue, oldValue);
        await info.setDexRouter(newValue)
        const newContractValue = await info.getDexRouter()
        assert.equal(newContractValue, newValue);
        await truffleAssert.reverts(info.setDexRouter(newValue, {
            'from': accounts[1]
        }));
    })

    it("should work the dexFactory", async () => {
        let oldValue = '0xBCfCcbde45cE874adCB698cC183deBcF17952812';
        let newValue = '0x0F4F2Ac550A1b4e2280d04c21cEa7EBD822934b5';
        const oldContractValue = await info.getDexFactory()
        assert.equal(oldContractValue, oldValue);
        await info.setDexFactory(newValue)
        const newContractValue = await info.getDexFactory()
        assert.equal(newContractValue, newValue);
        await truffleAssert.reverts(info.setDexFactory(newValue, {
            'from': accounts[1]
        }));
    })

    it("should work the PoolCreatorMinStake", async () => {
        let oldValue = new BN('100').mul(new BN(10).pow(new BN(18)));
        let newValue = new BN('10').mul(new BN(10).pow(new BN(18)));
        const oldContractValue = await info.getPoolCreatorMinStake();
        expect(oldContractValue).to.be.a.bignumber.that.equals(oldValue);
        await info.setPoolCreatorMinStake(newValue.toString())
        const newContractValue = await info.getPoolCreatorMinStake()
        expect(newContractValue).to.be.a.bignumber.that.equals(newValue);
        await truffleAssert.reverts(info.setPoolCreatorMinStake(newValue.toString(), {
            'from': accounts[1]
        }));
    })


})