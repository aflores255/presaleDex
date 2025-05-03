//1- License
// SPDX-License-Identifier: MIT

//2. Solidity Version
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/PresaleDex.sol";

// Mock ERC-20 Token

contract MockToken is ERC20("DexToken", "DEX") {
    function mint(address account, uint256 value) external {
        _mint(account, value);
    }
}

contract PresaleDexTest is Test {
    PresaleDex presale;
    address usdtAddress_ = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT Address in Arbitrum One
    address usdcAddress_ = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC Address in Arbitrum One
    address dataFeedAddress_ = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // Data Feed ETH/USD in Arbitrum One
    address fundsManager_ = vm.addr(1);
    address owner = vm.addr(2);
    address randomUser1 = vm.addr(3);
    address randomUser2 = vm.addr(4);
    address user1 = 0x4Af51BEb7475a686137bb1B7a9F941fb490961A1; // Holder USDC
    address user2 = 0x52Aa899454998Be5b000Ad077a46Bbe360F4e497; //Holder USDT
    uint256 maxSellAmount_ = 21000000 * 1e18; // 21 M Tokens
    uint256[][3] phases_; // Example: 5M tokens first phase, 6M second and 10M third, 0.01$ first phase and 50%+ each phase. 2 days per phase until 3 phase 4 days
    uint256 startTime_ = block.timestamp + 1;
    uint256 endTime_ = startTime_ + 864000; // 10 days
    MockToken mockToken;
    address presaleTokenAddress_;

    function setUp() public {
        phases_[0] = [5000000 * 1e18, 10000, block.timestamp + 172800];
        phases_[1] = [6000000 * 1e18, 15000, block.timestamp + 345600];
        phases_[2] = [10000000 * 1e18, 20000, block.timestamp + 518400];
        mockToken = new MockToken();
        presaleTokenAddress_ = address(mockToken);
        vm.startPrank(owner);
        mockToken.mint(owner, maxSellAmount_);
        presale = new PresaleDex(
            presaleTokenAddress_,
            usdtAddress_,
            usdcAddress_,
            dataFeedAddress_,
            fundsManager_,
            maxSellAmount_,
            phases_,
            startTime_,
            endTime_
        );
        vm.stopPrank();
    }

    function testInitialDeploy() public view {
        assert(presale.currentPhase() == 0);
        assert(presale.presaleTokenAddress() == address(mockToken));
        assert(presale.usdtAddress() == usdtAddress_);
        assert(presale.usdcAddress() == usdcAddress_);
        assert(presale.dataFeedAddress() == dataFeedAddress_);
        assert(presale.fundsManager() == fundsManager_);
        assert(presale.maxSellAmount() == maxSellAmount_);
        assert(presale.tokenSold() == 0);
    }

    function testIncorrectDates() public {
        startTime_ = block.timestamp;
        endTime_ = startTime_ - 1 days;
        vm.expectRevert("Incorrect time");
        presale = new PresaleDex(
            presaleTokenAddress_,
            usdtAddress_,
            usdcAddress_,
            dataFeedAddress_,
            fundsManager_,
            maxSellAmount_,
            phases_,
            startTime_,
            endTime_
        );
        endTime_ = startTime_ + 2 days;
        vm.expectRevert("Presale must be in the future");
        presale = new PresaleDex(
            presaleTokenAddress_,
            usdtAddress_,
            usdcAddress_,
            dataFeedAddress_,
            fundsManager_,
            maxSellAmount_,
            phases_,
            startTime_,
            endTime_
        );
    }

    function testDepositTokens() public {
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();
    }

    function testBlackListUser() public {
        vm.startPrank(owner);
        assert(!presale.isBlacklisted(randomUser1));
        presale.blackList(randomUser1);
        assert(presale.isBlacklisted(randomUser1));
        presale.removeFromBlackList(randomUser1);
        assert(!presale.isBlacklisted(randomUser1));
        vm.stopPrank();
    }

    function testCannotBlackListUser() public {
        vm.startPrank(randomUser2);
        assert(!presale.isBlacklisted(randomUser1));
        vm.expectRevert();
        presale.blackList(randomUser1);
        vm.stopPrank();
        vm.startPrank(owner);
        presale.blackList(randomUser1);
        assert(presale.isBlacklisted(randomUser1));
        vm.stopPrank();
        vm.startPrank(randomUser2);
        vm.expectRevert();
        presale.removeFromBlackList(randomUser1);
        vm.stopPrank();
    }

    function testBuyWithStable() public {
        uint256 amountToBuy = 100 * 1e6; // 100 usdc
        uint256 amountToBuy2 = 1000 * 1e6; // 1000 usdt
        uint256 balanceUSDCFundsManagerBefore = IERC20(usdcAddress_).balanceOf(fundsManager_);
        uint256 balanceUSDTFundsManagerBefore = IERC20(usdtAddress_).balanceOf(fundsManager_);
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();
        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 days);
        IERC20(usdcAddress_).approve(address(presale), amountToBuy);
        presale.buyWithStable(usdcAddress_, amountToBuy);
        uint256 calculatedTokensAmount =
            amountToBuy * 10 ** (18 - ERC20(usdcAddress_).decimals()) * 1e6 / phases_[presale.currentPhase()][1];
        assert(presale.tokenSold() == calculatedTokensAmount);
        assert(presale.userTokenBalance(user1) == calculatedTokensAmount);
        assert(IERC20(usdcAddress_).balanceOf(fundsManager_) == amountToBuy + balanceUSDCFundsManagerBefore);
        vm.startPrank(user2);
        IERC20(usdtAddress_).approve(address(presale), amountToBuy2);
        presale.buyWithStable(usdtAddress_, amountToBuy2);
        uint256 calculatedTokensAmount2 =
            amountToBuy2 * 10 ** (18 - ERC20(usdtAddress_).decimals()) * 1e6 / phases_[presale.currentPhase()][1];
        assert(presale.tokenSold() == calculatedTokensAmount + calculatedTokensAmount2);
        assert(presale.userTokenBalance(user2) == calculatedTokensAmount2);
        assert(IERC20(usdtAddress_).balanceOf(fundsManager_) == amountToBuy2 + balanceUSDTFundsManagerBefore);

        vm.stopPrank();
    }

    function testCannotBuyWithStableIfBlacklisted() public {
        uint256 amountToBuy = 100 * 1e6; // 100 usdc
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        presale.blackList(user1);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 days);
        IERC20(usdcAddress_).approve(address(presale), amountToBuy);
        vm.expectRevert("User blacklisted");
        presale.buyWithStable(usdcAddress_, amountToBuy);
        vm.stopPrank();
    }

    function testCannotBuyWithStableIncorrectFutureDate() public {
        uint256 amountToBuy = 100 * 1e6; // 100 usdc
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.warp(block.timestamp + 50 days);
        IERC20(usdcAddress_).approve(address(presale), amountToBuy);
        vm.expectRevert("Incorrect timestamp to buy");
        presale.buyWithStable(usdcAddress_, amountToBuy);
        vm.stopPrank();
    }

    function testCannotBuyWithStableIncorrectStartDate() public {
        uint256 amountToBuy = 100 * 1e6; // 100 usdc
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();

        vm.startPrank(user1);
        IERC20(usdcAddress_).approve(address(presale), amountToBuy);
        vm.expectRevert("Incorrect timestamp to buy");
        presale.buyWithStable(usdcAddress_, amountToBuy);
        vm.stopPrank();
    }

    function testCannotBuyWithStableIncorrectToken() public {
        uint256 amountToBuy = 100 * 1e18; // 100 DAI
        address daiAddress_ = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
        address daiHolder = 0xd9666262234CbAc5b00f949d3D95ef7c7c2191B5;
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();

        vm.startPrank(daiHolder);
        vm.warp(block.timestamp + 1 days);
        IERC20(daiAddress_).approve(address(presale), amountToBuy);
        vm.expectRevert("Incorrect ERC20 Token");
        presale.buyWithStable(daiAddress_, amountToBuy);
        vm.stopPrank();
    }

    function testCannotBuyWithStableNoTokensDeposited() public {
        uint256 amountToBuy = 100 * 1e6; // 100 usdc
        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 days);
        IERC20(usdcAddress_).approve(address(presale), amountToBuy);
        vm.expectRevert("Contract must have tokens to sell");
        presale.buyWithStable(usdcAddress_, amountToBuy);

        vm.stopPrank();
    }

    function testEmergencyWithdrawNotOwner() public {
        uint256 amount_ = 1e12;
        vm.startPrank(user1);
        vm.expectRevert();
        presale.emergencyWithdraw(usdcAddress_, amount_);
        vm.stopPrank();
    }

    function testEmergencyWithdrawEtherNotOwner() public {
        vm.startPrank(user1);
        vm.expectRevert();
        presale.emergencyWithdrawEther();
        vm.stopPrank();
    }

    function testEmergencyWithdrawEtherOwner() public {
        vm.startPrank(owner);
        presale.emergencyWithdrawEther();
        vm.stopPrank();
    }

    function testEmergencyWithdrawOwner() public {
        uint256 amount_ = 100 * 1e6;
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        presale.emergencyWithdraw(address(mockToken), amount_);
        assert(IERC20(mockToken).balanceOf(owner) == amount_);
        vm.stopPrank();
    }

    function testGetEtherPrice() public view {
        uint256 realPrice = 1800 * 1e18; // Ensure aprox. price feed is ok change if necessary
        uint256 etherPrice = presale.getEtherPrice();
        assert(etherPrice > realPrice);
    }

    function testDepositNoOwner() public {
        vm.startPrank(user1);
        mockToken.mint(user1, maxSellAmount_);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        vm.expectRevert();
        presale.depositTokens();
        vm.stopPrank();
    }

    function testBuyWithEther() public {
        uint256 amountToBuy = 10 ether; // 10 ether
        uint256 balanceFundsManagerBefore = fundsManager_.balance;
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();
        vm.startPrank(user1);
        vm.deal(user1, amountToBuy);
        vm.warp(block.timestamp + 1 days);
        presale.buyWithEther{value: amountToBuy}();
        assert(presale.tokenSold() > 0);
        assert(presale.userTokenBalance(user1) > 0);
        assert(fundsManager_.balance > balanceFundsManagerBefore);
        vm.stopPrank();
    }

    function testCannotBuyWithEtherIfBlacklisted() public {
        uint256 amountToBuy = 10 ether; // 10 ether
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        presale.blackList(user1);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(user1, amountToBuy);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert("User blacklisted");
        presale.buyWithEther{value: amountToBuy}();
        vm.stopPrank();
    }

    function testCannotBuyWithEtherIncorrectFutureDate() public {
        uint256 amountToBuy = 10 ether; // 10 ether
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(user1, amountToBuy);
        vm.warp(block.timestamp + 50 days);
        vm.expectRevert("Incorrect timestamp to buy");
        presale.buyWithEther{value: amountToBuy}();
        vm.stopPrank();
    }

    function testCannotBuyWithEtherIncorrectStartDate() public {
        uint256 amountToBuy = 10 ether; // 10 ether
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(user1, amountToBuy);
        vm.expectRevert("Incorrect timestamp to buy");
        presale.buyWithEther{value: amountToBuy}();
        vm.stopPrank();
    }

    function testCannotBuyWithEtherNoTokensDeposited() public {
        uint256 amountToBuy = 10 ether; // 10 ether
        vm.startPrank(user1);
        vm.deal(user1, amountToBuy);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert("Contract must have tokens to sell");
        presale.buyWithEther{value: amountToBuy}();
        vm.stopPrank();
    }

    function testClaimTokensIncorrectDate() public {
        uint256 amountToBuy = 100 * 1e6; // 100 usdc
        uint256 balanceUSDCFundsManagerBefore = IERC20(usdcAddress_).balanceOf(fundsManager_);
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();
        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 days);
        IERC20(usdcAddress_).approve(address(presale), amountToBuy);
        presale.buyWithStable(usdcAddress_, amountToBuy);
        uint256 calculatedTokensAmount =
            amountToBuy * 10 ** (18 - ERC20(usdcAddress_).decimals()) * 1e6 / phases_[presale.currentPhase()][1];
        assert(presale.tokenSold() == calculatedTokensAmount);
        assert(presale.userTokenBalance(user1) == calculatedTokensAmount);
        assert(IERC20(usdcAddress_).balanceOf(fundsManager_) == amountToBuy + balanceUSDCFundsManagerBefore);

        vm.expectRevert("Presale not finished");
        presale.claimTokens();
        vm.stopPrank();
    }

    function testClaimNoPurchase() public {
        uint256 amountToBuy = 100 * 1e6; // 100 usdc
        uint256 balanceUSDCFundsManagerBefore = IERC20(usdcAddress_).balanceOf(fundsManager_);
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();
        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 days);
        IERC20(usdcAddress_).approve(address(presale), amountToBuy);
        presale.buyWithStable(usdcAddress_, amountToBuy);
        uint256 calculatedTokensAmount =
            amountToBuy * 10 ** (18 - ERC20(usdcAddress_).decimals()) * 1e6 / phases_[presale.currentPhase()][1];
        assert(presale.tokenSold() == calculatedTokensAmount);
        assert(presale.userTokenBalance(user1) == calculatedTokensAmount);
        assert(IERC20(usdcAddress_).balanceOf(fundsManager_) == amountToBuy + balanceUSDCFundsManagerBefore);

        vm.warp(endTime_ + 1 days);
        vm.stopPrank();
        vm.startPrank(user2);
        vm.expectRevert("No tokens to claim");
        presale.claimTokens();
        vm.stopPrank();
    }

    function testClaimCorrectly() public {
        uint256 amountToBuy = 100 * 1e6; // 100 usdc
        uint256 balanceUSDCFundsManagerBefore = IERC20(usdcAddress_).balanceOf(fundsManager_);
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();
        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 days);
        IERC20(usdcAddress_).approve(address(presale), amountToBuy);
        presale.buyWithStable(usdcAddress_, amountToBuy);
        uint256 calculatedTokensAmount =
            amountToBuy * 10 ** (18 - ERC20(usdcAddress_).decimals()) * 1e6 / phases_[presale.currentPhase()][1];
        assert(presale.tokenSold() == calculatedTokensAmount);
        assert(presale.userTokenBalance(user1) == calculatedTokensAmount);
        assert(IERC20(usdcAddress_).balanceOf(fundsManager_) == amountToBuy + balanceUSDCFundsManagerBefore);

        vm.warp(endTime_ + 1 days);

        presale.claimTokens();
        assert(IERC20(mockToken).balanceOf(user1) == calculatedTokensAmount);

        vm.stopPrank();
    }

    function testSoldOutBuyWithStable() public {
        uint256 amountToBuy = 500000 * 1e6; // 500k usdc
        uint256 amountToBuy2 = 1000 * 1e6; // 1000 usdt
        uint256 balanceUSDTFundsManagerBefore = IERC20(usdtAddress_).balanceOf(fundsManager_);
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(user2);
        IERC20(usdtAddress_).approve(address(presale), amountToBuy2);
        presale.buyWithStable(usdtAddress_, amountToBuy2);
        uint256 calculatedTokensAmount2 =
            amountToBuy2 * 10 ** (18 - ERC20(usdtAddress_).decimals()) * 1e6 / phases_[presale.currentPhase()][1];
        assert(presale.tokenSold() == calculatedTokensAmount2);
        assert(presale.userTokenBalance(user2) == calculatedTokensAmount2);
        assert(IERC20(usdtAddress_).balanceOf(fundsManager_) == amountToBuy2 + balanceUSDTFundsManagerBefore);
        vm.startPrank(user1);
        IERC20(usdcAddress_).approve(address(presale), amountToBuy);
        vm.expectRevert("Sold Out");
        presale.buyWithStable(usdcAddress_, amountToBuy);
        vm.stopPrank();
    }

    function testSoldOutBuyWithEther() public {
        uint256 amountToBuy = 1000 * 1e18; // 1000 ether
        uint256 amountToBuy2 = 1000 * 1e6; // 1000 usdt
        uint256 balanceUSDTFundsManagerBefore = IERC20(usdtAddress_).balanceOf(fundsManager_);
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(user2);
        IERC20(usdtAddress_).approve(address(presale), amountToBuy2);
        presale.buyWithStable(usdtAddress_, amountToBuy2);
        uint256 calculatedTokensAmount2 =
            amountToBuy2 * 10 ** (18 - ERC20(usdtAddress_).decimals()) * 1e6 / phases_[presale.currentPhase()][1];
        assert(presale.tokenSold() == calculatedTokensAmount2);
        assert(presale.userTokenBalance(user2) == calculatedTokensAmount2);
        assert(IERC20(usdtAddress_).balanceOf(fundsManager_) == amountToBuy2 + balanceUSDTFundsManagerBefore);
        vm.startPrank(user1);
        vm.deal(user1, amountToBuy);
        vm.expectRevert("Sold Out");
        presale.buyWithEther{value: amountToBuy}();
        vm.stopPrank();
    }

    function testChangePhase() public {
        uint256 amountToBuy = 100 * 1e6; // 100 usdc
        uint256 amountToBuy2 = 1000 * 1e6; // 1000 usdt
        uint256 balanceUSDCFundsManagerBefore = IERC20(usdcAddress_).balanceOf(fundsManager_);
        uint256 balanceUSDTFundsManagerBefore = IERC20(usdtAddress_).balanceOf(fundsManager_);
        vm.startPrank(owner);
        IERC20(mockToken).approve(address(presale), maxSellAmount_);
        presale.depositTokens();
        assert(IERC20(mockToken).balanceOf(address(presale)) == maxSellAmount_);
        vm.stopPrank();
        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 days);
        IERC20(usdcAddress_).approve(address(presale), amountToBuy);
        presale.buyWithStable(usdcAddress_, amountToBuy);
        uint256 calculatedTokensAmount =
            amountToBuy * 10 ** (18 - ERC20(usdcAddress_).decimals()) * 1e6 / phases_[presale.currentPhase()][1];
        assert(presale.tokenSold() == calculatedTokensAmount);
        assert(presale.userTokenBalance(user1) == calculatedTokensAmount);
        assert(IERC20(usdcAddress_).balanceOf(fundsManager_) == amountToBuy + balanceUSDCFundsManagerBefore);
        vm.startPrank(user2);
        vm.warp(block.timestamp + 172801); // phase 2
        IERC20(usdtAddress_).approve(address(presale), amountToBuy2);
        presale.buyWithStable(usdtAddress_, amountToBuy2);
        assert(IERC20(usdtAddress_).balanceOf(fundsManager_) == amountToBuy2 + balanceUSDTFundsManagerBefore);
        assert(presale.currentPhase() == 1);
        vm.warp(block.timestamp + 345601); // phase 3
        IERC20(usdtAddress_).approve(address(presale), amountToBuy2);
        presale.buyWithStable(usdtAddress_, amountToBuy2);
        assert(presale.currentPhase() == 2);

        vm.stopPrank();
    }
}
