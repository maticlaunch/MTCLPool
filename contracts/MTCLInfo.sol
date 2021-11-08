// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MTCLInfo is Ownable {
    using SafeMath for uint256;

    uint256 private devFeePercentage = 2; // fees going to dev AND MTCL hodlers (2% each)
    uint256 private minDevFeeInWei = 5 ether; // min fee amount going to dev AND MTCL hodlers

    address[] private poolAddresses; // track all pools created

    uint256 private minInvestorMTCLBalance = 100 * 1e18; // min amount to investors HODL MTCL balance
    uint256 private minStakeTime = 24 hours;
    uint256 private minUnstakeTime = 24 hours;
    uint256 private poolCreatorStake = 100 * 1e18;
    uint256 private guaranteedAllocationTime = 12 hours;


    address private dexRouter =
        address(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    address private dexFactory =
        address(0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32);
    address private usdt = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);

    address private mtclFactoryAddress;

    modifier onlyFactory() {
        require(mtclFactoryAddress == msg.sender);
        _;
    }

    function getMTCLFactoryAddress() external view returns (address) {
        return mtclFactoryAddress;
    }

    function setMTCLFactoryAddress(address _newFactoryAddress)
        external
        onlyOwner
    {
        mtclFactoryAddress = _newFactoryAddress;
    }

    function addPoolAddress(address _pool)
        external
        onlyFactory
        returns (uint256)
    {
        poolAddresses.push(_pool);
        return poolAddresses.length - 1;
    }

    function getPoolsCount() external view returns (uint256) {
        return poolAddresses.length;
    }

    function getPoolAddress(uint256 mtclPoolId) external view returns (address) {
        return poolAddresses[mtclPoolId];
    }

    function getPoolCreatorMinStake() external view returns (uint256) {
        return poolCreatorStake;
    }

    function setPoolCreatorMinStake(uint256 _minStake) external onlyOwner {
        poolCreatorStake = _minStake;
    }

    function getDevFeePercentage() external view returns (uint256) {
        return devFeePercentage;
    }

    function setDevFeePercentage(uint256 _devFeePercentage) external onlyOwner {
        devFeePercentage = _devFeePercentage;
    }

    function getMinDevFeeInWei() external view returns (uint256) {
        return minDevFeeInWei;
    }

    function setMinDevFeeInWei(uint256 _minDevFeeInWei) external onlyOwner {
        minDevFeeInWei = _minDevFeeInWei;
    }

    function getMinInvestorMTCLBalance() external view returns (uint256) {
        return minInvestorMTCLBalance;
    }

    function setMinInvestorMTCLBalance(uint256 _minInvestorMTCLBalance)
        external
        onlyOwner
    {
        minInvestorMTCLBalance = _minInvestorMTCLBalance;
    }

    function getMinStakeTime() external view returns (uint256) {
        return minStakeTime;
    }

    function setMinStakeTime(uint256 _minStakeTime) external onlyOwner {
        minStakeTime = _minStakeTime;
    }

    function getMinUnstakeTime() external view returns (uint256) {
        return minUnstakeTime;
    }

    function setMinUnstakeTime(uint256 _minUnstakeTime) external onlyOwner {
        minUnstakeTime = _minUnstakeTime;
    }

    function getGuaranteedAllocationTime() external view returns (uint256) {
        return guaranteedAllocationTime;
    }

    function setGuaranteedAllocationTime(uint256 _guaranteedAllocationTime) external onlyOwner {
        guaranteedAllocationTime = _guaranteedAllocationTime;
    }

    function getDexRouter() external view returns (address) {
        return dexRouter;
    }

    function setDexRouter(address _dexRouter)
        external
        onlyOwner
    {
        dexRouter = _dexRouter;
    }

    function getDexFactory() external view returns (address) {
        return dexFactory;
    }

    function setDexFactory(address _dexFactory)
        external
        onlyOwner
    {
        dexFactory = _dexFactory;
    }

    function getUSDT() external view returns (address) {
        return usdt;
    }

    function setUSDT(address _usdt) external onlyOwner {
        usdt = _usdt;
    }
    
}