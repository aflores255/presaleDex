# 🚀 PresaleDex

## 📌 Description

**PresaleDex** is a Solidity smart contract that enables users to participate in a token presale using **ETH** or **stablecoins** (USDT, USDC). The presale is structured in multiple **phases**, each with its own cap and price. It also features a **blacklist system**, **claim logic**, and full compatibility with **Foundry** for testing.

Built with **Solidity 0.8.28**, the contract is designed for secure on-chain token distribution, and integrates with Chainlink's ETH/USD **price feed** on **Arbitrum One**.

---

## 🧩 Features

| **Feature**               | **Description**                                                                 |
|---------------------------|---------------------------------------------------------------------------------|
| 🪙 **Token Presale**       | Sell presale tokens in multiple price phases with supply limits.               |
| 💵 **Buy with Stablecoins**| Purchase tokens using USDT or USDC.                                            |
| 🌐 **Buy with ETH**        | Automatically converts ETH to USD via Chainlink price feed.                    |
| 📈 **Phase Tracking**      | Automatically transitions to new presale phases based on time or sales volume.|
| 🛡️ **Blacklist Control**   | Block specific addresses from participating in the presale.                   |
| 📤 **Token Claiming**      | Users can claim their tokens once the presale ends.                          |
| 🧪 **Foundry Test Suite**  | Complete test coverage for edge cases and flows.                              |

---

## 📜 Contract Details

### ⚙️ Constructor

```solidity
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
)
```

Initializes the presale with token addresses, price feed, caps, and presale timeframe.

---

### 🔧 Functions

| **Function**                | **Description**                                                              |
|-----------------------------|------------------------------------------------------------------------------|
| `buyWithStable()`           | Buys presale tokens using USDT or USDC.                                     |
| `buyWithEther()`            | Buys presale tokens using ETH, priced via Chainlink.                        |
| `claimTokens()`             | Allows users to claim their tokens after presale ends.                      |
| `depositTokens()`           | Owner deposits presale tokens into contract.                                |
| `emergencyWithdraw()`       | Owner can withdraw ERC20 tokens in case any user sent tokens to the contract|
| `emergencyWithdrawEther()`  | Owner can withdraw ETH from the contract.                                   |
| `blackList()`               | Blacklists a user from participating.                                       |
| `removeFromBlackList()`     | Removes a user from the blacklist.                                          |
| `getEtherPrice()`           | Fetches latest ETH/USD price from Chainlink aggregator.                     |

---

### 📡 Events

| **Event**         | **Description**                          |
|-------------------|------------------------------------------|
| `TokenBuy`        | Emitted on successful purchase.          |
| `DepositTokens`   | Emitted when presale tokens are deposited.|

---

### 🔐 Modifiers & Validations

- Ensures only supported tokens (USDT/USDC) are accepted.
- Verifies presale is within the defined time window.
- Validates user is not blacklisted.
- Prevents overselling above `maxSellAmount`.

---

## 🧪 Testing with Foundry

All functions are tested with **Foundry**, using real addresses and Chainlink feeds on **Arbitrum One**.

### ✅ Implemented Tests

| **Test**                             | **Description**                                       |
|--------------------------------------|-------------------------------------------------------|
| `testInitialDeploy`                  | Verifies contract setup.                             |
| `testDepositTokens`                 | Tests token deposit logic.                           |
| `testBuyWithStable`                  | Tests USDT/USDC purchases.                           |
| `testBuyWithEther`                   | Tests ETH purchases and price conversion.            |
| `testClaimTokens`                    | Ensures token claim flow works post-presale.         |
| `testCannotBuyIfBlacklisted`         | Validates blacklist logic.                           |
| `testCannotBuyOutsideDateRange`      | Ensures time constraints are respected.              |
| `testCannotBuyWithWrongToken`        | Rejects unsupported tokens like DAI.                 |
| `testSoldOutLimit`                   | Reverts when max token cap is reached.               |
| `testEmergencyWithdraws`             | Only owner can withdraw tokens/ETH.                  |
| `testChangePhase`                    | Verifies automatic phase updates over time/sales.    |
| `testIncorrectStartEndDate`          | Ensures constructor reverts on invalid dates.        |

---

## 🔗 Dependencies

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Foundry](https://book.getfoundry.sh/)
- [Chainlink Aggregator](https://docs.chain.link/data-feeds/)
- [`IAggregator.sol`](https://github.com/aflores255/presaleDex/blob/master/src/interfaces/IAggregator.sol)

---

## 🛠️ How to Use

### 🔧 Prerequisites

- Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Access to **Arbitrum One**
- Wallet with ETH, USDT or USDC
- Deploy the presale token

---

### 🧪 Run Tests

```bash
forge test
```

---

### 🚀 Deployment

1. Clone the repository:

```bash
git clone https://github.com/aflores255/PresaleDex.git
cd PresaleDex
```

2. Deploy contract:

```solidity
new PresaleDex(presaleToken, usdt, usdc, chainlinkFeed, fundsManager, maxSell, phases, start, end);
```

Use valid addresses and well-defined phase structure:
```solidity
phases = [
  [5000000 * 1e18, 10000, block.timestamp + 2 days],
  [6000000 * 1e18, 15000, block.timestamp + 4 days],
  [10000000 * 1e18, 20000, block.timestamp + 6 days]
];
```

---

## 📄 License

This project is licensed under the **MIT License**.
