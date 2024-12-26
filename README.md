# Multi-Signature Wallet Smart Contract

A secure and decentralized multi-signature wallet implementation on the Ethereum blockchain that requires multiple approvals for transactions.

## Features

### Wallet Management
- Multiple wallet owners
- Configurable approval threshold
- Add/remove wallet owners (except main owner)
- View all wallet owners

### Financial Operations
- Deposit ETH
- Withdraw deposited funds
- Create transfer requests
- Approve pending transfers
- Cancel pending transfers
- Automatic transfer execution when threshold is met

### Security Features
- Immutable main owner
- Only owners can perform administrative actions
- Transfer sender cannot approve their own transfers
- Transfers require multiple approvals based on threshold
- Comprehensive error handling
- Transfer status tracking (Pending, Success, Cancelled)

### Transparency
- Detailed event logging for all operations
- View contract balance
- View individual deposit balances
- View all transfers and their status
- Check transfer approvals
- View approval status for specific owners
