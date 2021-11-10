// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/utils/Address.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MTCLInfo.sol";

contract MTCLStaking is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    IERC20 public mtclToken;
    MTCLInfo public mtclInfo;

    uint256 public totalStaked;

    event Staked(address indexed from, uint256 amount);
    event Unstaked(address indexed from, uint256 amount);

    struct StakerInfo {
        uint256 balance;
        uint256 lastStakedTimestamp;
        uint256 lastUnstakedTimestamp;
    }
    mapping(address => StakerInfo) public stakerInfos;

    constructor(address _mtclToken, address _mtclInfo) {
        mtclToken = IERC20(_mtclToken);
        mtclInfo = MTCLInfo(_mtclInfo);
    }

    function stake(uint256 _amount) public nonReentrant {
        require(_amount > 0, "Invalid amount");
        require(mtclToken.balanceOf(msg.sender) >= _amount, "Invalid balance");
        uint256 minStakeAmount = mtclInfo.getMinInvestorMTCLBalance();

        StakerInfo storage account = stakerInfos[msg.sender];
        mtclToken.safeTransferFrom(msg.sender, address(this), _amount);
        account.balance = account.balance.add(_amount);
        require(account.balance >= minStakeAmount, "MTCLStaking: min stake required");
        totalStaked = totalStaked.add(_amount);
        account.lastStakedTimestamp = block.timestamp;
        if (account.lastUnstakedTimestamp == 0) {
            account.lastUnstakedTimestamp = block.timestamp;
        }
        emit Staked(msg.sender, _amount);
    }

    function unstake(uint256 _amount, uint256 _burnFeePercent)
        external
        nonReentrant
    {
        StakerInfo storage account = stakerInfos[msg.sender];
        require(_burnFeePercent < 100);
        uint256 minUnstakeTime = mtclInfo.getMinUnstakeTime();
        require(
            account.lastStakedTimestamp + minUnstakeTime <= block.timestamp,
            "Invalid unstake time"
        );
        require(account.balance > 0, "Nothing to unstake");
        require(_amount > 0, "Invalid amount");
        if (account.balance < _amount) {
            _amount = account.balance;
        }
        // require(
        //     account.balance.sub(_amount) >= minStakeAmount ||
        //         (account.balance.sub(_amount) < minStakeAmount &&
        //             account.balance == _amount),
        //     "MTCLStaking: min stake required"
        // );
        account.balance = account.balance.sub(_amount);
        totalStaked = totalStaked.sub(_amount);
        account.lastUnstakedTimestamp = block.timestamp;

        uint256 burnAmount = _amount.mul(_burnFeePercent).div(100);
        if (burnAmount > 0) {
            _amount = _amount.sub(burnAmount);
            mtclToken.transfer(
                address(0x000000000000000000000000000000000000dEaD),
                burnAmount
            );
        }

        mtclToken.safeTransfer(msg.sender, _amount);
        emit Unstaked(msg.sender, _amount);
    }
}
