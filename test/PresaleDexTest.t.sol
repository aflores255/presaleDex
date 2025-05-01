//1- License
// SPDX-License-Identifier: MIT

//2. Solidity Version
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/PresaleDex.sol";

contract PresaleDexTest is Test{

    PresaleDex presale;
    address presaleTokenAddress_ = vm.addr(1); // mockToken
    address usdtAddress_ = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT Address in Arbitrum One
    address usdcAddress_ = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC Address in Arbitrum One
    address dataFeedAddress_ = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // Data Feed ETH/USD in Arbitrum One
    address fundsManager_ = vm.addr(2);
    uint256 maxSellAmount_ = 21000000 * 1e18; // 21 M Tokens
    uint256[][3] phases_; // Example: 5M tokens first phase, 6M second and 10M third, 0.1$ first phase and 50%+ each phase. 2 days per phase until 3 phase 4 days
    uint256 startTime_ = block.timestamp;
    uint256 endTime_ = block.timestamp + 864000; // 10 days


    function setUp() public{

        phases_[0] = [5000000 * 1e18, 100000, block.timestamp+172800];
        phases_[1] = [6000000, 150000, block.timestamp+345600];
        phases_[2] = [10000000, 200000, block.timestamp+518400];

        presale = new PresaleDex(presaleTokenAddress_,usdtAddress_,usdcAddress_,dataFeedAddress_,fundsManager_,maxSellAmount_,phases_,startTime_,endTime_);


    }


}

