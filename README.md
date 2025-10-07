# 💰 Rate-Limited Wallet

> A smart contract wallet that enforces daily spending limits to teach throttling concepts and promote responsible spending habits.

## 🌟 Features

- 🚀 **Create Wallet**: Set up your wallet with a custom daily spending limit
- 💳 **Deposit Funds**: Add STX tokens to your wallet securely
- 🏧 **Controlled Withdrawals**: Withdraw funds within your daily limit
- 📊 **Daily Reset**: Spending limits automatically reset every 144 blocks (~24 hours)
- 🔧 **Limit Updates**: Modify your daily spending limit anytime
- 🆘 **Emergency Withdraw**: Complete wallet drainage for emergencies
- 📈 **Transaction History**: Track your spending patterns and history
- 📋 **Wallet Analytics**: View detailed wallet statistics and remaining limits
- 🤝 **Delegation System**: Grant controlled spending permissions to trusted parties
- ⏰ **Scheduled Withdrawals**: Automate one-time or recurring payments

## 🏗️ Contract Architecture

The Rate-Limited Wallet implements a throttling mechanism that:
- Tracks daily spending per wallet
- Automatically resets limits every 144 blocks
- Maintains transaction history for analytics
- Provides emergency access when needed

## 📖 Usage Instructions

### 🎯 Creating a Wallet

```clarity
(contract-call? .rate-limited-wallet create-wallet u1000000)
```
Creates a new wallet with a daily limit of 1 STX (1,000,000 micro-STX).

### 💰 Depositing Funds

```clarity
(contract-call? .rate-limited-wallet deposit u500000)
```
Deposits 0.5 STX into your wallet.

### 🏧 Withdrawing Funds

```clarity
(contract-call? .rate-limited-wallet withdraw u200000)
```
Withdraws 0.2 STX (if within daily limit).

### ⚙️ Updating Daily Limit

```clarity
(contract-call? .rate-limited-wallet update-daily-limit u2000000)
```
Updates daily spending limit to 2 STX.

### 🆘 Emergency Withdrawal

```clarity
(contract-call? .rate-limited-wallet emergency-withdraw)
```
Withdraws entire wallet balance (bypasses daily limits).

## 🔍 Read-Only Functions

### 📊 Get Wallet Information

```clarity
(contract-call? .rate-limited-wallet get-wallet-info 'SP123...)
```

Returns:
- Current balance
- Daily limit and spent amount
- Remaining daily allowance
- Reset timing information
- Wallet creation details

### 📈 Check Withdrawal Feasibility

```clarity
(contract-call? .rate-limited-wallet check-withdrawal-allowed 'SP123... u100000)
```

Validates if a withdrawal is possible without executing it.

### 📋 View Daily History

```clarity
(contract-call? .rate-limited-wallet get-daily-history 'SP123... u1)
```

Shows spending history for a specific day.

### 🔢 Contract Statistics

```clarity
(contract-call? .rate-limited-wallet get-contract-stats)
```

Displays overall contract metrics and usage statistics.

### ⏰ Scheduling Withdrawals

```clarity
(contract-call? .rate-limited-wallet schedule-withdrawal 'SP123... u500000 u1000 false u0 u0)
```

Schedules a one-time withdrawal of 0.5 STX at block 1000.

### 📅 Recurring Payments

```clarity
(contract-call? .rate-limited-wallet schedule-withdrawal 'SP123... u100000 u1000 true u144 u30)
```

Schedules recurring withdrawals of 0.1 STX every 144 blocks for 30 executions.

### ⚡ Executing Scheduled Payments

```clarity
(contract-call? .rate-limited-wallet execute-scheduled-withdrawal 'SP-OWNER... u0)
```

Anyone can execute a scheduled withdrawal when the block height is reached.

### 🚫 Canceling Schedules

```clarity
(contract-call? .rate-limited-wallet cancel-scheduled-withdrawal u0)
```

Cancel an active scheduled withdrawal.

### 📊 Schedule Information

```clarity
(contract-call? .rate-limited-wallet get-schedule-info 'SP-OWNER... u0)
```

View schedule details including execution readiness.

## ⚡ Key Concepts

### 🕒 Daily Reset Mechanism
- **Block-based timing**: Uses 144 blocks ≈ 24 hours
- **Automatic reset**: Spending limits refresh each day
- **Seamless operation**: No manual intervention required

### 🛡️ Safety Features
- **Balance validation**: Ensures sufficient funds before withdrawal
- **Limit enforcement**: Strict daily spending caps
- **Emergency access**: Complete wallet drainage option
- **Transaction logging**: Full audit trail

### 📊 Analytics & Tracking
- **Daily summaries**: Spending totals per day
- **Transaction details**: Individual transaction records
- **Wallet insights**: Usage patterns and statistics

## 🚀 Getting Started

1. **Deploy the contract** using Clarinet
2. **Create your wallet** with `create-wallet`
3. **Deposit funds** using `deposit`
4. **Start spending** within your daily limits
5. **Monitor usage** with read-only functions

## ⚠️ Important Notes

- Daily limits reset every 144 blocks (~24 hours on Stacks mainnet)
- Emergency withdrawal bypasses all limits
- All amounts are in micro-STX (1 STX = 1,000,000 micro-STX)
- Transaction history is permanently stored on-chain

## 🔒 Error Codes

| Code | Description |
|------|-------------|
| u100 | Insufficient balance |
| u101 | Daily limit exceeded |
| u102 | Invalid amount (zero or negative) |
| u103 | Not authorized |
| u104 | Wallet not found |
| u105 | Wallet already initialized |
| u106 | Delegation not found |
| u107 | Already delegated |
| u108 | Cannot delegate to self |
| u109 | Schedule not found |
| u110 | Schedule not ready for execution |
| u111 | Schedule already executed |
| u112 | Schedule cancelled |
| u113 | Invalid schedule parameters |

## 🎯 Use Cases

- 🏦 **Personal budgeting** with enforced limits
- 👨‍🎓 **Learning throttling** concepts in blockchain
- 🔐 **Controlled access** to large funds
- 📚 **Educational demonstrations** of rate limiting
- 💼 **Corporate expense** management
- 👪 **Family allowances** with delegation controls
- 💳 **Automated subscriptions** via scheduled payments
- 🏠 **Recurring rent payments** without manual intervention
- 🔄 **Payroll automation** for periodic disbursements

---

*Built with ❤️ using Clarity and Clarinet*
