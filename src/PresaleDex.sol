//1- License
// SPDX-License-Identifier: MIT

//2. Solidity Version
pragma solidity 0.8.28;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// 3. Contract

contract PresaleDex is Ownable {
    using SafeERC20 for IERC20;
    //Variables
    address public usdtAddress;
    address public usdcAddress;
    address public fundsManager;
    uint256 public maxSellAmount;
    uint256[][3] public phases;
    mapping(address => bool) public isBlacklisted;
    uint256 startTime;
    uint256 endTime;

    //Constructor
    constructor(
        address usdtAddress_,
        address usdcAddress_,
        address fundsManager_,
        uint256 maxSellAmount_,
        uint256[][3] memory phases_,
        uint256 startTime_,
        uint256 endTime_
    ) Ownable(msg.sender) {
        usdcAddress = usdcAddress_;
        usdtAddress = usdtAddress_;
        fundsManager = fundsManager_;
        maxSellAmount = maxSellAmount_;
        phases = phases_;
        startTime = startTime_;
        endTime = endTime_;

        require(endTime > startTime,"Incorrect time");
        require(startTime > block.timestamp,"Presale must be in the future");
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
     * 
     * 
     */
    function buyWithStable() external {
        require(!isBlacklisted[msg.sender], "User blacklisted");
        require(block.timestamp >= startTime,"Presale not started yet");
    }

    function emergencyWithdraw(address token_, uint256 amount_) onlyOwner() external{
        IERC20(token_).safeTransfer(msg.sender,amount_);

    }

    function emergyWithdrawEther() onlyOwner() external{
        uint256 scBalance = address(this).balance;
        (bool success,) = msg.sender.call{value: scBalance}("");
        require(success, "Withdraw failed");
    }
}
