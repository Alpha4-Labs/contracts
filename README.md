# Alpha Points Protocol - Smart Contracts

![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)
[![Move](https://img.shields.io/badge/Move-Sui-blue.svg)](https://docs.sui.io/)

This repository contains the **Alpha Points Protocol smart contracts** implementation for the Sui blockchain. The protocol enables the minting, management, and redemption of Alpha Points - account-bound units of cross-chain liquidity and loyalty - secured by object-isolated stakes on Sui.

## 🏗️ Repository Structure

```
├── sources/           # Move smart contract source files
│   ├── admin.move            # Protocol administration & governance
│   ├── ledger.move           # Point accounting & balance management  
│   ├── escrow.move           # Asset custody & vault management
│   ├── stake_position.move   # Individual stake objects
│   ├── oracle.move           # Price feeds & conversion rates
│   ├── integration.move      # Main protocol entry points
│   ├── partner.move          # Partner management system
│   ├── partner_flex.move     # Flexible partner configurations
│   ├── partner_yield.move    # Partner yield calculations
│   ├── perk_manager.move     # Perk creation & redemption
│   ├── generation_manager.move # Generation-based rewards
│   ├── staking_manager.move  # Staking operations
│   ├── loan.move             # Lending against stakes
│   └── ...
├── tests/             # Move unit tests
├── Move.toml          # Package manifest
└── Move.lock          # Dependency lock file
```

## 🧩 Core Protocol Modules

### Essential Infrastructure
- **`admin.move`** - Configuration, capabilities, and emergency controls
- **`ledger.move`** - Global Alpha Point supply and user balance accounting
- **`escrow.move`** - Secure custody of underlying assets backing points
- **`oracle.move`** - External price feeds and conversion rate management

### User-Facing Operations
- **`integration.move`** - Main protocol interface for users and applications
- **`stake_position.move`** - Individual stake representations as Sui objects
- **`staking_manager.move`** - Staking lifecycle management

### Partner & Rewards System
- **`partner.move`** - Partner onboarding and management
- **`partner_flex.move`** - Flexible partner reward configurations
- **`partner_yield.move`** - Partner-specific yield calculations
- **`perk_manager.move`** - Perk creation, pricing, and redemption
- **`generation_manager.move`** - Generation-based reward distributions

### Advanced Features
- **`loan.move`** - Collateralized lending against staked positions
- **`pending_withdrawals_manager.move`** - Withdrawal queue management

## ⚡ Key Features

### Account-Bound Points
- Points are **non-transferable** by design, tied to user addresses
- Prevents gaming through wash trading or artificial transfers
- Maintains authentic engagement tracking

### Object-Centric Security
- Each stake is its own `StakePosition` object with the `key` ability
- Compromise blast-radius is limited to individual objects
- Enhanced security through isolation

### Flexible Partner Integration
- Partners can integrate using stable APIs without core modifications
- Configurable reward parameters and perk systems
- Generation-based and yield-based reward models

### Upgradability & Governance
- Package uses upgrade capabilities for compatible improvements
- Governance controls through capability objects
- Emergency pause functionality for security

## 📊 Points Generation Formula

```
points = principal × participation × time_weight × (1 / liquidity_dom)
```

This formula is implemented as pure Move math inside the `ledger` module for deterministic, on-chain results.

## 🔧 Development Setup

### Prerequisites
- [Sui CLI](https://docs.sui.io/guides/developer/getting-started/sui-install) installed
- Move development environment configured

### Building the Contracts

```bash
# Clone the repository
git clone https://github.com/Alpha4-Labs/contracts.git
cd contracts

# Build the Move package
sui move build

# Run tests
sui move test
```

### Testing

The `tests/` directory contains comprehensive unit tests for all modules:

```bash
# Run specific test module
sui move test --test admin_tests

# Run all tests with coverage
sui move test --coverage
```

## 🚀 Deployment Phases

1. **α-0 Core Ledger** - Basic points accounting ✅
2. **α-1 Stake + Escrow** - Full staking and redemption flows ✅  
3. **α-2 Partner System** - Partner integration and perk management ✅
4. **α-3 Loan Module** - Early-exit capability via loans ✅
5. **α-4 Advanced Features** - Generation management and yield optimization ✅

## 🔒 Security Features

- **Emergency Controls** - Protocol-wide pause functionality
- **Capability-Based Access** - Explicit authorization through capability objects
- **Comprehensive Events** - Full event emission for all state changes
- **Extensive Testing** - Complete test coverage across all modules
- **Error Handling** - Descriptive error codes and proper error management

## 🔗 Related Repositories

This contracts repository is part of the larger Alpha Points ecosystem:

- **Frontend Application** - User dashboard and staking interface
- **Partner Dashboard** - Partner management and analytics  
- **Rewards Marketplace** - Perk browsing and redemption
- **SDK** - JavaScript/TypeScript integration library
- **Documentation** - Protocol specifications and guides

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and add tests
4. Ensure all tests pass: `sui move test`
5. Commit your changes: `git commit -m 'Add amazing feature'`
6. Push to the branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues** - Report bugs or request features via [GitHub Issues](https://github.com/Alpha4-Labs/contracts/issues)
- **Documentation** - Check our comprehensive docs repository
- **Community** - Join our Discord for discussions and support

---

**Alpha4 Labs** - Building the future of cross-chain liquidity and engagement rewards.
