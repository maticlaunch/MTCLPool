// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./MTCLStaking.sol";

interface IDexV2Router02 {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );
}

contract MTCLPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address internal mtclFactoryAddress; // address that creates the pool contracts
    address public mtclOwnerAddress; // address where dev fees will be transferred to
    address public mtclLiqLockAddress; // address where LP tokens will be locked
    MTCLStaking public mtclStaking;
    MTCLInfo public MTCLInfoObj;

    IERC20 public token; // token that will be sold
    IERC20 public usdtToken; //usdt token that will be invested
    address public poolCreatorAddress; // address where percentage of invested wei will be transferred to
    address public unsoldTokensDumpAddress; // address where unsold tokens will be transferred to

    mapping(address => uint256) public investments; // total wei invested per address
    mapping(address => uint256) public whitelistedAddressesWeightage; // addresses eligible in pool with respective weightage
    mapping(address => bool) public refunded; // if true, it means investor already got a refund
    mapping(address => uint256) public claimTracker; // if 1, it means investor already claimed initial release, afterwards vesting iterations

    uint256 private mtclOwnerFeePercentage; // dev fee to support the development of MTCL
    uint256 private mtclMinOwnerFeeInWei; // minimum fixed dev fee to support the development of MTCL
    uint256 public mtclPoolId; // used for fetching pool without referencing its address

    uint256 public totalInvestorsCount; // total investors count
    uint256 public poolCreatorClaimTime; // time when pool creator can collect funds raise
    uint256 public totalWhitelistedAddressesWeightage; //total weightage of all whitelisted
    uint256 public totalCollectedWei; // total wei collected
    uint256 public leftCollectedWei; // after dev fees what ever is left
    uint256 public totalTokens; // total tokens to be sold
    uint256 public tokensLeft; // available tokens to be sold
    uint256 public tokenPriceInWei; // token pool wei price per 1 token
    uint256 public hardCapInWei; // maximum wei amount that can be invested in pool
    uint256 public softCapInWei; // minimum wei amount to invest in pool, if not met, invested wei will be returned
    uint256 public maxInvestInWei; // maximum wei amount that can be invested per wallet address
    uint256 public minInvestInWei; // minimum wei amount that can be invested per wallet address
    uint256 public openTime; // time when pool starts, investing is allowed
    uint256 public closeTime; // time when pool closes, investing is not allowed
    uint256 public multiplier = 1;
    uint256 public listingReleasePercent; //initial release of token in Percentage
    uint256 public vestingWindow; //vesting windows in days
    uint256 public vestingIteration; // in how many window vesting will happen
    uint256 public lpToken; //token recived for lp provison
    uint256 public lpListingPriceInWei; // token price when listed in Dex
    uint256 public lpLiquidityAddingTime; // time when adding of liquidity in Dex starts, investors can claim their tokens afterwards
    uint256 public lpLPTokensLockDurationInDays; // how many days after the liquity is added the pool creator can unlock the LP tokens
    uint256 public lpLiquidityPercentageAllocation; // how many percentage of the total invested wei that will be added as liquidity
    uint256 public liqPoolTokenAmount; // this much token added to lp after fees dudection
    bool public poolWithoutLiquidity = false; //pool without automatic lp addition
    bool public mtclOwnerApproved = false;

    mapping(address => uint256) public voters; // addresses voting on sale
    uint256 public noVotes; // total number of no votes
    uint256 public yesVotes; // total number of yes votes
    uint256 public minYesVotesThreshold = 1000 * 1e18; // minimum number of yes votes needed to pass
    uint256 public minVoterMTCLBalance = 10 * 1e18; // minimum number of MTCL tokens to hold to vote

    bool public lpLiquidityAdded = false; // if true, liquidity is added in Dex and lp tokens are locked
    bool public onlyWhitelistedAddressesAllowed = false; // if true, whitelisted addresses also can invest
    bool public mtclOwnerFeesExempted = false; // if true, pool will be exempted from dev fees
    bool public poolCancelled = false; // if true, investing will not be allowed, investors can withdraw, pool creator can withdraw their tokens
    bool public isUnsoldTokenBurned = false;

    bytes32 public saleTitle;
    bytes32 public linkTelegram;
    bytes32 public linkTwitter;
    bytes32 public linkWebsite;
    bytes32 public linkLogo;

    constructor(
        address _mtclFactoryAddress,
        address _mtclInfoAddress,
        address _mtclOwnerAddress
    ) {
        require(_mtclFactoryAddress != address(0));
        require(_mtclOwnerAddress != address(0));

        mtclFactoryAddress = payable(_mtclFactoryAddress);
        mtclOwnerAddress = payable(_mtclOwnerAddress);
        MTCLInfoObj = MTCLInfo(_mtclInfoAddress);
    }

    modifier onlyMTCLOwner() {
        require(
            mtclFactoryAddress == msg.sender || mtclOwnerAddress == msg.sender
        );
        _;
    }

    modifier onlyPoolCreatorOrMTCLFactoryOrMTCLOwner() {
        require(
            poolCreatorAddress == msg.sender ||
                mtclFactoryAddress == msg.sender ||
                mtclOwnerAddress == msg.sender
        );
        _;
    }

    modifier onlyPoolCreatorOrMTCLOwner() {
        require(
            poolCreatorAddress == msg.sender || mtclOwnerAddress == msg.sender
        );
        _;
    }

    modifier poolIsNotCancelled() {
        require(!poolCancelled, "Cancelled");
        _;
    }

    modifier investorOnly() {
        require(investments[msg.sender] > 0, "Not investor");
        _;
    }

    modifier notYetClaimedOrRefunded() {
        require(
            !refunded[msg.sender] && claimTracker[msg.sender] == 0,
            "Already claimed or refunded"
        );
        _;
    }

    modifier votesPassed() {
        require(
            (mtclOwnerApproved) ||
                (yesVotes > noVotes && yesVotes >= minYesVotesThreshold),
            "Votes not passed"
        );
        _;
    }

    function setAddressInfo(
        address _poolCreator,
        address _tokenAddress,
        address _usdtTokenAddress,
        address _unsoldTokensDumpAddress
    ) external onlyPoolCreatorOrMTCLFactoryOrMTCLOwner {
        require(_poolCreator != address(0));
        require(_tokenAddress != address(0));
        require(_unsoldTokensDumpAddress != address(0));

        poolCreatorAddress = payable(_poolCreator);
        token = IERC20(_tokenAddress);
        usdtToken = IERC20(_usdtTokenAddress);
        unsoldTokensDumpAddress = _unsoldTokensDumpAddress;
    }

    function setGeneralInfo(
        uint256 _totalTokens,
        uint256 _lpToken,
        uint256 _tokenPriceInWei,
        uint256 _hardCapInWei,
        uint256 _softCapInWei,
        uint256 _maxInvestInWei,
        uint256 _minInvestInWei,
        uint256 _openTime,
        uint256 _closeTime
    ) external onlyPoolCreatorOrMTCLFactoryOrMTCLOwner {
        require(_totalTokens > 0);
        require(_tokenPriceInWei > 0);
        require(_openTime > 0);
        require(_closeTime > 0);
        require(_hardCapInWei > 0);

        // Hard cap > (token amount * token price)
        require(_hardCapInWei <= _totalTokens.mul(_tokenPriceInWei), "hardcap");
        // Soft cap > to hard cap
        require(_softCapInWei <= _hardCapInWei, "softcap");
        //  Min. wei investment > max. wei investment
        require(_minInvestInWei <= _maxInvestInWei, "minMax");
        // Open time >= close time
        require(_openTime < _closeTime, "opneClose");

        totalTokens = _totalTokens;
        tokensLeft = _totalTokens;
        lpToken = _lpToken;
        tokenPriceInWei = _tokenPriceInWei;
        hardCapInWei = _hardCapInWei;
        softCapInWei = _softCapInWei;
        maxInvestInWei = _maxInvestInWei;
        minInvestInWei = _minInvestInWei;
        openTime = _openTime;
        closeTime = _closeTime;
    }

    function setDexInfo(
        uint256 _lpListingPriceInWei,
        uint256 _lpLiquidityAddingTime,
        uint256 _lpLPTokensLockDurationInDays,
        uint256 _lpLiquidityPercentageAllocation,
        bool _poolWithoutLiquidity
    ) external onlyPoolCreatorOrMTCLFactoryOrMTCLOwner {
        require(_lpListingPriceInWei > 0);
        require(_lpLiquidityAddingTime > 0);
        require(_lpLPTokensLockDurationInDays > 0);
        require(_lpLiquidityPercentageAllocation > 0);

        require(closeTime > 0);
        // Listing time < close time
        require(_lpLiquidityAddingTime >= closeTime, "lpClose");

        lpListingPriceInWei = _lpListingPriceInWei;
        lpLiquidityAddingTime = _lpLiquidityAddingTime;
        lpLPTokensLockDurationInDays = _lpLPTokensLockDurationInDays;
        lpLiquidityPercentageAllocation = _lpLiquidityPercentageAllocation;
        poolWithoutLiquidity = _poolWithoutLiquidity;
    }

    function setStringInfo(
        bytes32 _saleTitle,
        bytes32 _linkTelegram,
        bytes32 _linkTwitter,
        bytes32 _linkWebsite,
        bytes32 _linkLogo
    ) external onlyPoolCreatorOrMTCLFactoryOrMTCLOwner {
        saleTitle = _saleTitle;
        linkTelegram = _linkTelegram;
        linkTwitter = _linkTwitter;
        linkWebsite = _linkWebsite;
        linkLogo = _linkLogo;
    }

    function setMTCLInfo(
        address _mtclLiqLockAddress,
        uint256 _mtclOwnerFeePercentage,
        uint256 _mtclMinOwnerFeeInWei,
        uint256 _mtclPoolId,
        address _mtclStaking
    ) external onlyMTCLOwner {
        mtclLiqLockAddress = _mtclLiqLockAddress;
        mtclOwnerFeePercentage = _mtclOwnerFeePercentage;
        mtclMinOwnerFeeInWei = _mtclMinOwnerFeeInWei;
        mtclPoolId = _mtclPoolId;
        mtclStaking = MTCLStaking(_mtclStaking);
    }

    function setVestingInfo(
        uint256 _listingReleasePercent,
        uint256 _vestingWindow,
        uint256 _vestingIteration
    ) external onlyPoolCreatorOrMTCLFactoryOrMTCLOwner {
        require(listingReleasePercent <= 100);
        listingReleasePercent = _listingReleasePercent;
        vestingWindow = _vestingWindow;
        vestingIteration = _vestingIteration;
    }

    function setMTCLDevFeesExempted(bool _mtclOwnerFeesExempted)
        external
        onlyMTCLOwner
    {
        mtclOwnerFeesExempted = _mtclOwnerFeesExempted;
    }

    function setWhitelistedAddressesAllowed(
        bool _onlyWhitelistedAddressesAllowed
    ) external onlyMTCLOwner {
        onlyWhitelistedAddressesAllowed = _onlyWhitelistedAddressesAllowed;
    }

    function setMTCLOwnerApproved(bool _mtclOwnerApproved)
        external
        onlyMTCLOwner
    {
        mtclOwnerApproved = _mtclOwnerApproved;
    }

    function setMultiplier(uint256 _multiplier) external onlyMTCLOwner {
        require(block.timestamp < openTime);
        require(multiplier >= 1);
        multiplier = _multiplier;
    }

    function setminVoterMTCLBalance(uint256 _minVoterMTCLBalance)
        external
        onlyMTCLOwner
    {
        require(_minVoterMTCLBalance >= 10 * 1e18);
        minVoterMTCLBalance = _minVoterMTCLBalance * 1e18;
    }

    function setMinYesVotesThreshold(uint256 _minYesVotesThreshold)
        external
        onlyMTCLOwner
    {
        require(_minYesVotesThreshold >= 10000 * 1e18);
        minYesVotesThreshold = _minYesVotesThreshold * 1e18;
    }

    function addWhitelistedAddresses(
        address[] calldata _whitelistedAddresses,
        uint256[] calldata _weightage
    ) external onlyMTCLOwner {
        require(_whitelistedAddresses.length == _weightage.length);
        for (uint256 i = 0; i < _whitelistedAddresses.length; i++) {
            totalWhitelistedAddressesWeightage = totalWhitelistedAddressesWeightage
                .sub(whitelistedAddressesWeightage[_whitelistedAddresses[i]]);
            whitelistedAddressesWeightage[
                _whitelistedAddresses[i]
            ] = _weightage[i];
            totalWhitelistedAddressesWeightage = totalWhitelistedAddressesWeightage
                .add(_weightage[i]);
        }
    }

    function getGuaranteedInvestAmount()
        public
        view
        returns (uint256 min, uint256 max)
    {
        uint256 weightage;
        if (onlyWhitelistedAddressesAllowed) {
            weightage = whitelistedAddressesWeightage[msg.sender]
                .mul(multiplier)
                .mul(10**18)
                .div(totalWhitelistedAddressesWeightage);
        } else {
            uint256 balance;
            uint256 lastStakedTimestamp;
            uint256 lastUnstakedTimestamp;
            uint256 totalStaked;
            uint256 mtclBalance;
            (balance, lastStakedTimestamp, lastUnstakedTimestamp) = mtclStaking
                .stakerInfos(msg.sender);
            totalStaked = mtclStaking.totalStaked();
            uint256 minStakeTime = MTCLInfoObj.getMinStakeTime();
            if (lastStakedTimestamp + minStakeTime <= block.timestamp) {
                mtclBalance = mtclBalance.add(balance);
            }
            if (whitelistedAddressesWeightage[msg.sender] > 0) {
                mtclBalance = mtclBalance.add(
                    whitelistedAddressesWeightage[msg.sender]
                );
            }
            weightage = mtclBalance.mul(multiplier).mul(10**18).div(
                totalStaked.add(totalWhitelistedAddressesWeightage)
            );
        }

        return (0, hardCapInWei.mul(weightage).div(10**18));
    }

    function invest(uint256 _investmentAmount)
        public
        poolIsNotCancelled
        votesPassed
    {
        require(block.timestamp >= openTime, "a");
        require(block.timestamp < closeTime, "b");
        require(totalCollectedWei < hardCapInWei, "c");
        require(tokensLeft > 0, "d");
        require(_investmentAmount > 0, "e");
        require(
            usdtToken.balanceOf(msg.sender) >= _investmentAmount,
            "Insufficent balance"
        );

        uint256 minInvest;
        uint256 maxInvest;

        if (
            openTime.add(MTCLInfoObj.getGuaranteedAllocationTime()) >
            block.timestamp
        ) {
            (minInvest, maxInvest) = getGuaranteedInvestAmount();
        } else {
            minInvest = minInvestInWei;
            maxInvest = maxInvestInWei;
        }

        require(
            _investmentAmount <= tokensLeft.mul(tokenPriceInWei).div(1e18),
            "f"
        );

        uint256 totalInvestmentInWei = investments[msg.sender].add(
            _investmentAmount
        );
        require(totalInvestmentInWei >= minInvest, "g");
        require(maxInvest == 0 || totalInvestmentInWei <= maxInvest, "h");

        if (investments[msg.sender] == 0) {
            totalInvestorsCount = totalInvestorsCount.add(1);
        }

        usdtToken.safeTransferFrom(
            msg.sender,
            address(this),
            _investmentAmount
        );
        totalCollectedWei = totalCollectedWei.add(_investmentAmount);
        investments[msg.sender] = totalInvestmentInWei;
        tokensLeft = tokensLeft.sub(
            _investmentAmount.mul(1e18).div(tokenPriceInWei)
        );
    }

    function setAllowClaim() external onlyMTCLOwner {
        require(poolWithoutLiquidity);
        require(totalCollectedWei >= softCapInWei);
        require(!lpLiquidityAdded);
        lpLiquidityAdded = true;
        uint256 mtclDevFeeInWei;
        uint256 finalTotalCollectedWei = totalCollectedWei;
        if (!mtclOwnerFeesExempted) {
            uint256 pctDevFee = totalCollectedWei
                .mul(mtclOwnerFeePercentage)
                .div(100);
            mtclDevFeeInWei = pctDevFee > mtclMinOwnerFeeInWei ||
                mtclMinOwnerFeeInWei >= finalTotalCollectedWei
                ? pctDevFee
                : mtclMinOwnerFeeInWei;
        }
        if (mtclDevFeeInWei > 0) {
            finalTotalCollectedWei = finalTotalCollectedWei.sub(
                mtclDevFeeInWei
            );
            usdtToken.safeTransfer(mtclOwnerAddress, mtclDevFeeInWei);
        }

        leftCollectedWei = finalTotalCollectedWei;
        poolCreatorClaimTime = block.timestamp;
    }

    function addLiquidityAndLockLPTokens()
        external
        poolIsNotCancelled
        onlyPoolCreatorOrMTCLOwner
    {
        require(totalCollectedWei > 0);
        require(!lpLiquidityAdded);
        require(!poolWithoutLiquidity);
        require(block.timestamp >= lpLiquidityAddingTime);
        require(totalCollectedWei >= softCapInWei);

        lpLiquidityAdded = true;

        uint256 finalTotalCollectedWei = totalCollectedWei;

        uint256 mtclDevFeeInWei;
        if (!mtclOwnerFeesExempted) {
            uint256 pctDevFee = totalCollectedWei
                .mul(mtclOwnerFeePercentage)
                .div(100);
            mtclDevFeeInWei = pctDevFee > mtclMinOwnerFeeInWei ||
                mtclMinOwnerFeeInWei >= finalTotalCollectedWei
                ? pctDevFee
                : mtclMinOwnerFeeInWei;
        }
        if (mtclDevFeeInWei > 0) {
            finalTotalCollectedWei = finalTotalCollectedWei.sub(
                mtclDevFeeInWei
            );
            usdtToken.safeTransfer(mtclOwnerAddress, mtclDevFeeInWei);
        }

        uint256 liqPoolUSDTAmount = finalTotalCollectedWei
            .mul(lpLiquidityPercentageAllocation)
            .div(100);
        liqPoolTokenAmount = liqPoolUSDTAmount.mul(1e18).div(
            lpListingPriceInWei
        );

        IDexV2Router02 dexRouter = IDexV2Router02(
            address(MTCLInfoObj.getDexRouter())
        );

        usdtToken.approve(address(dexRouter), liqPoolUSDTAmount);
        token.approve(address(dexRouter), liqPoolTokenAmount);

        dexRouter.addLiquidity(
            address(token),
            address(usdtToken),
            liqPoolTokenAmount,
            liqPoolUSDTAmount,
            0,
            0,
            mtclLiqLockAddress,
            block.timestamp.add(15 minutes)
        );

        finalTotalCollectedWei = finalTotalCollectedWei.sub(liqPoolUSDTAmount);

        leftCollectedWei = finalTotalCollectedWei;
        poolCreatorClaimTime = block.timestamp;
    }

    function vote(bool yes) external poolIsNotCancelled {
        require(block.timestamp < openTime);
        uint256 balance;
        uint256 lastStakedTimestamp;
        uint256 lastUnstakedTimestamp;
        (balance, lastStakedTimestamp, lastUnstakedTimestamp) = mtclStaking
            .stakerInfos(msg.sender);
        uint256 minStakeTime = MTCLInfoObj.getMinStakeTime();
        uint256 voterBalance = 0;

        if (lastStakedTimestamp + minStakeTime <= block.timestamp) {
            voterBalance = voterBalance.add(balance);
        }

        require(voterBalance >= minVoterMTCLBalance);
        require(voters[msg.sender] == 0);

        voters[msg.sender] = voterBalance;
        if (yes) {
            yesVotes = yesVotes.add(voterBalance);
        } else {
            noVotes = noVotes.add(voterBalance);
        }
    }

    function claimInitial() external investorOnly poolIsNotCancelled {
        require(lpLiquidityAdded, "early");
        require(claimTracker[msg.sender] == 0);
        uint256 totalClaimable = (investments[msg.sender]).mul(1e18).div(
            tokenPriceInWei
        );
        uint256 initialClaim = totalClaimable.mul(listingReleasePercent).div(
            100
        );
        claimTracker[msg.sender] = 1;
        token.safeTransfer(msg.sender, initialClaim);
    }

    function claimVestingTokens() external investorOnly poolIsNotCancelled {
        require(lpLiquidityAdded, "early");
        require(vestingIteration > 0);
        require(claimTracker[msg.sender] >= 1, "Initial claim required");
        uint256 claimable;
        uint256 totalClaimable = (investments[msg.sender]).mul(1e18).div(
            tokenPriceInWei
        );
        uint256 initialClaim = totalClaimable.mul(listingReleasePercent).div(
            100
        );
        totalClaimable = totalClaimable.sub(initialClaim);
        uint256 claimableVestCount = (block.timestamp)
            .sub(lpLiquidityAddingTime)
            .div(vestingWindow.mul(1 minutes));
        claimableVestCount = (claimableVestCount > vestingIteration)
            ? vestingIteration
            : claimableVestCount;
        claimableVestCount = claimableVestCount.sub(
            claimTracker[msg.sender].sub(1)
        );
        require(claimableVestCount > 0);
        claimable = totalClaimable.mul(claimableVestCount).div(
            vestingIteration
        );
        claimTracker[msg.sender] = claimTracker[msg.sender].add(
            claimableVestCount
        );
        require(claimable > 0, "Nothing to claim");
        token.safeTransfer(msg.sender, claimable);
    }

    function getRefund() external investorOnly notYetClaimedOrRefunded {
        if (!poolCancelled) {
            require(block.timestamp >= openTime, "Not opened");
            require(block.timestamp >= closeTime, "Not closed");
            require(softCapInWei > 0, "No soft cap");
            require(totalCollectedWei < softCapInWei, "Soft cap reached");
        }

        refunded[msg.sender] = true; // make sure this goes first before transfer to prevent reentrancy
        uint256 investment = investments[msg.sender];
        // uint256 poolBalance = address(this).balance;
        uint256 poolBalance = usdtToken.balanceOf(address(this));
        require(poolBalance > 0);

        if (investment > poolBalance) {
            investment = poolBalance;
        }

        if (investment > 0) {
            // msg.sender.transfer(investment);
            usdtToken.safeTransfer(msg.sender, investment);
        }
    }

    function cancelAndTransferTokensToPresaleCreator() external {
        if (
            !lpLiquidityAdded &&
            poolCreatorAddress != msg.sender &&
            mtclOwnerAddress != msg.sender
        ) {
            revert();
        }
        if (lpLiquidityAdded && mtclOwnerAddress != msg.sender) {
            revert();
        }

        require(!poolCancelled);
        poolCancelled = true;

        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.safeTransfer(poolCreatorAddress, balance);
        }
    }

    function collectFundsRaised() external onlyPoolCreatorOrMTCLOwner {
        require(lpLiquidityAdded);
        require(!poolCancelled);
        require(block.timestamp >= poolCreatorClaimTime);

        if (usdtToken.balanceOf(address(this)) > 0) {
            usdtToken.safeTransfer(poolCreatorAddress, leftCollectedWei);
        }
    }

    function burnUnsoldTokens() external onlyPoolCreatorOrMTCLOwner {
        require(lpLiquidityAdded);
        require(!poolCancelled);
        require(block.timestamp >= poolCreatorClaimTime); // wait 1 days before allowing burn
        require(!isUnsoldTokenBurned);

        isUnsoldTokenBurned = true;

        uint256 leftOutPart = (hardCapInWei.sub(totalCollectedWei))
            .mul(1e18)
            .div(tokenPriceInWei);
        leftOutPart = leftOutPart.add(lpToken.sub(liqPoolTokenAmount));

        if (leftOutPart > 0) {
            token.safeTransfer(unsoldTokensDumpAddress, leftOutPart);
        }
    }
}
