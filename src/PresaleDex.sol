//1- License
// SPDX-License-Identifier: MIT

//2. Solidity Version
pragma solidity 0.8.28;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IAggregator.sol";

// 3. Contract

contract PresaleDex is Ownable {
    using SafeERC20 for IERC20;
    //Variables

    address presaleTokenAddress;
    address public usdtAddress;
    address public usdcAddress;
    address public fundsManager;
    address dataFeedAddress;
    uint256 public maxSellAmount;
    uint256[][3] public phases;
    mapping(address => bool) public isBlacklisted;
    uint256 startTime;
    uint256 endTime;
    uint256 tokenSold;
    mapping(address => uint256) userTokenBalance;
    uint256 public currentPhase;

    //Events
    event TokenBuy(address user, uint256 amount);

    //Constructor
    constructor(
        address presaleTokenAddress_,
        address usdtAddress_,
        address usdcAddress_,
        address dataFeedAddress_,
        address fundsManager_,
        uint256 maxSellAmount_,
        uint256[][3] memory phases_,
        uint256 startTime_,
        uint256 endTime_
    ) Ownable(msg.sender) {
        presaleTokenAddress = presaleTokenAddress_;
        usdcAddress = usdcAddress_;
        usdtAddress = usdtAddress_;
        fundsManager = fundsManager_;
        maxSellAmount = maxSellAmount_;
        phases = phases_;
        startTime = startTime_;
        endTime = endTime_;
        dataFeedAddress = dataFeedAddress_;

        require(endTime > startTime, "Incorrect time");
        require(startTime > block.timestamp, "Presale must be in the future");
        IERC20(presaleTokenAddress).safeTransferFrom(msg.sender, address(this), maxSellAmount);
    }

    //Functions

    /**
     * Add user to blacklist in order to avoid purchase of tokens
     * @param user_ user to be added to the blacklist
     */
    function blackList(address user_) external onlyOwner {
        isBlacklisted[user_] = true;
    }

    /**
     * Remove user from the current blacklist
     * @param user_ user to be removed from the blacklist
     */
    function removeFromBlackList(address user_) external onlyOwner {
        isBlacklisted[user_] = false;
    }

    /**
     * Buy tokens with stable coin
     * @param tokenForBuying_ address of ERC token to buy
     * @param amount_ amount of tokens for buying
     */
    function buyWithStable(address tokenForBuying_, uint256 amount_) external {
        require(!isBlacklisted[msg.sender], "User blacklisted");
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Incorrect timestamp to buy");
        require(tokenForBuying_ == usdcAddress || tokenForBuying_ == usdtAddress, "Incorrect ERC20 Token");

        uint256 tokenAmountToReceive;
        if (ERC20(tokenForBuying_).decimals() == 18) {
            tokenAmountToReceive = amount_ * 1e6 / phases[currentPhase][1];
        } // 18 decimals
        else {
            tokenAmountToReceive =
                amount_ * 10 ** (18 - ERC20(tokenForBuying_).decimals()) * 1e6 / phases[currentPhase][1];
        }

        checkCurrentPhase(tokenAmountToReceive);
        tokenSold += tokenAmountToReceive;

        require(tokenSold <= maxSellAmount, "Sold Out");

        userTokenBalance[msg.sender] += tokenAmountToReceive;

        IERC20(tokenForBuying_).safeTransferFrom(msg.sender, fundsManager, amount_);

        emit TokenBuy(msg.sender, tokenAmountToReceive);
    }
    /**
     * Buy tokens with ether
     */

    function buyWithEther() external payable {
        require(!isBlacklisted[msg.sender], "User blacklisted");
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Incorrect timestamp to buy");

        uint256 tokenAmountToReceive;
        uint256 usdValue = msg.value * getEtherPrice() / 1e18;
        tokenAmountToReceive = usdValue * 1e6 / phases[currentPhase][1];
        checkCurrentPhase(tokenAmountToReceive);
        tokenSold += tokenAmountToReceive;
        require(tokenSold <= maxSellAmount, "Sold Out");

        userTokenBalance[msg.sender] += tokenAmountToReceive;
        (bool success,) = fundsManager.call{value: msg.value}("");
        require(success, "Payment failed");
        emit TokenBuy(msg.sender, tokenAmountToReceive);
    }

    /**
     * Get Ether current price using dataFeed
     */
    function getEtherPrice() public view returns (uint256) {
        (, int256 price,,,) = IAggregator(dataFeedAddress).latestRoundData();
        price = price * (10 ** 10);
        return uint256(price);
    }

    /**
     * Withdraw tokens from SC only for owner
     * @param token_ address of ERC token to withdraw
     * @param amount_ amount of tokens to withdraw
     */
    function emergencyWithdraw(address token_, uint256 amount_) external onlyOwner {
        IERC20(token_).safeTransfer(msg.sender, amount_);
    }
    /**
     * Withdraw ether from SC only for owner
     */

    function emergyWithdrawEther() external onlyOwner {
        uint256 scBalance = address(this).balance;
        (bool success,) = msg.sender.call{value: scBalance}("");
        require(success, "Withdraw failed");
    }

    /**
     * Claim tokens once presale is finished
     */
    function claimTokens() external {
        require(block.timestamp > endTime, "Presale not finished");

        uint256 userAmount = userTokenBalance[msg.sender];
        delete userTokenBalance[msg.sender];

        IERC20(presaleTokenAddress).safeTransfer(msg.sender, userAmount);
    }
    /**
     * Get current phase of the presale
     * @param amount_ amount of tokens sold
     */

    function checkCurrentPhase(uint256 amount_) private returns (uint256 phase) {
        if (
            tokenSold + amount_ >= phases[currentPhase][0]
                || (block.timestamp >= phases[currentPhase][2]) && currentPhase < 3
        ) {
            currentPhase++;
            phase = currentPhase;
        } else {
            phase = currentPhase;
        }
    }
}
