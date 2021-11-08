// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import "./MTCLPool.sol";

contract MTCLTimeLocker is TokenTimelock {
    constructor(
        IERC20 _token,
        uint256 _releaseTime,
        address primaryBeneficiary
    ) TokenTimelock(_token, primaryBeneficiary, _releaseTime) {}
}

interface IDexV2Factory {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

contract MTCLFactory is ReentrancyGuard {
    using SafeMath for uint256;

    event PoolCreated(bytes32 title, uint256 mtclPoolId, address creator);

    MTCLInfo public immutable MTCLInfoObj;
    IERC20 public mtclToken;

    MTCLStaking public mtclStakingPool;

    // mapping(address => uint256) public lastClaimedTimestamp;

    constructor(
        address _mtclInfoAddress,
        address _mtclToken,
        address _mtclStakingPool
    ) {
        MTCLInfoObj = MTCLInfo(_mtclInfoAddress);
        mtclToken = IERC20(_mtclToken);
        mtclStakingPool = MTCLStaking(_mtclStakingPool);
    }

    struct PoolInfo {
        address tokenAddress;
        address unsoldTokensDumpAddress;
        uint256 tokenPriceInWei;
        uint256 hardCapInWei;
        uint256 softCapInWei;
        uint256 maxInvestInWei;
        uint256 minInvestInWei;
        uint256 openTime;
        uint256 closeTime;
    }

    struct PoolDexInfo {
        uint256 listingPriceInWei;
        uint256 liquidityAddingTime;
        uint256 lpTokensLockDurationInDays;
        uint256 liquidityPercentageAllocation;
        bool poolWithoutLiquidity;
    }

    struct PoolStringInfo {
        bytes32 saleTitle;
        bytes32 linkTelegram;
        bytes32 linkTwitter;
        bytes32 linkWebsite;
        bytes32 linkLogo;
    }

    struct PoolVestingInfo {
        uint256 listingReleasePercent;
        uint256 vestingWindow;
        uint256 vestingIteration;
    }

    // calculates the CREATE2 address for a pair without making any external calls
    // https://docs.soliditylang.org/en/develop/080-breaking-changes.html#new-restrictions
    //TODO: hex change:- 96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f
    function lpV2LibPairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        require(tokenA != tokenB, "pair");
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
                        )
                    )
                )
            )
        );
    }

    function initializePool(
        MTCLPool _pool,
        uint256 _totalTokens,
        uint256 _lpToken,
        PoolInfo calldata _info,
        PoolDexInfo calldata _lpInfo,
        PoolStringInfo calldata _stringInfo
    ) internal {
        _pool.setAddressInfo(
            msg.sender,
            _info.tokenAddress,
            MTCLInfoObj.getUSDT(),
            _info.unsoldTokensDumpAddress
        );
        _pool.setGeneralInfo(
            _totalTokens,
            _lpToken,
            _info.tokenPriceInWei,
            _info.hardCapInWei,
            _info.softCapInWei,
            _info.maxInvestInWei,
            _info.minInvestInWei,
            _info.openTime,
            _info.closeTime
        );
        _pool.setDexInfo(
            _lpInfo.listingPriceInWei,
            _lpInfo.liquidityAddingTime,
            _lpInfo.lpTokensLockDurationInDays,
            _lpInfo.liquidityPercentageAllocation,
            _lpInfo.poolWithoutLiquidity
        );
        _pool.setStringInfo(
            _stringInfo.saleTitle,
            _stringInfo.linkTelegram,
            _stringInfo.linkTwitter,
            _stringInfo.linkWebsite,
            _stringInfo.linkLogo
        );
    }

    function createPool(
        PoolInfo calldata _info,
        PoolDexInfo calldata _lpInfo,
        PoolStringInfo calldata _stringInfo,
        PoolVestingInfo calldata _vestingInfo
    ) external {
        uint256 balance;
        uint256 lastStakedTimestamp;
        uint256 lastUnstakedTimestamp;
        (balance, lastStakedTimestamp, lastUnstakedTimestamp) = mtclStakingPool
            .stakerInfos(msg.sender);
        require(balance >= MTCLInfoObj.getPoolCreatorMinStake());
        IERC20 token = IERC20(_info.tokenAddress);

        MTCLPool pool = new MTCLPool(
            address(this),
            address(MTCLInfoObj),
            MTCLInfoObj.owner()
        );

        uint256 maxTokensToBeSold = _info.hardCapInWei.mul(1e18).div(
            _info.tokenPriceInWei
        );
        uint256 maxLiqPoolTokenAmount = 0;
        if (_lpInfo.poolWithoutLiquidity) {
            require(msg.sender == MTCLInfoObj.owner());
        } else {
            uint256 maxUSDTPoolTokenAmount = _info
                .hardCapInWei
                .mul(_lpInfo.liquidityPercentageAllocation)
                .div(100);
            maxLiqPoolTokenAmount = maxUSDTPoolTokenAmount.mul(1e18).div(
                _lpInfo.listingPriceInWei
            );
        }

        uint256 requiredTokenAmount = maxLiqPoolTokenAmount.add(
            maxTokensToBeSold
        );
        require(
            token.transferFrom(msg.sender, address(pool), requiredTokenAmount)
        );

        initializePool(
            pool,
            maxTokensToBeSold,
            maxLiqPoolTokenAmount,
            _info,
            _lpInfo,
            _stringInfo
        );

        MTCLTimeLocker liquidityLock;

        if (!_lpInfo.poolWithoutLiquidity) {
            IDexV2Factory dexFactory = IDexV2Factory(
                MTCLInfoObj.getDexFactory()
            );

            address pairAddress = lpV2LibPairFor(
                address(dexFactory),
                address(token),
                MTCLInfoObj.getUSDT()
            );
            liquidityLock = new MTCLTimeLocker(
                IERC20(pairAddress),
                _lpInfo.liquidityAddingTime +
                    (_lpInfo.lpTokensLockDurationInDays * 1 days),
                msg.sender
            );
        }

        uint256 mtclPoolId = MTCLInfoObj.addPoolAddress(address(pool));
        pool.setMTCLInfo(
            address(liquidityLock),
            MTCLInfoObj.getDevFeePercentage(),
            MTCLInfoObj.getMinDevFeeInWei(),
            mtclPoolId,
            address(mtclStakingPool)
        );

        pool.setVestingInfo(
            _vestingInfo.listingReleasePercent,
            _vestingInfo.vestingWindow,
            _vestingInfo.vestingIteration
        );

        emit PoolCreated(_stringInfo.saleTitle, mtclPoolId, msg.sender);
    }
}
