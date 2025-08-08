# Alpha4 - Production-Ready Move Smart Contracts

**A secure, scalable, and DeFi-compatible points protocol built on Sui blockchain.**

## 🎯 Protocol Overview

Alpha4 is a comprehensive points protocol designed for enterprise-grade partner integrations. The protocol enables partners to mint non-transferable points backed by USDC collateral, with built-in DeFi compatibility and automated revenue distribution.

### Key Design Principles

- **🔒 Security First**: Fixed all critical vulnerabilities from V1 with comprehensive validation
- **💰 Stable Value**: USDC-only collateral eliminates volatility risk
- **🌐 DeFi Compatible**: Vault objects designed for protocols like Scallop and Haedal
- **⚡ Production Ready**: Enterprise-grade architecture with proper error handling
- **🔄 Upgrade Safe**: Maintains backward compatibility with clear migration paths

---

## 📚 Architecture Overview

### Core Modules (Active)

| Module | Purpose | Status | Key Features |
|--------|---------|--------|--------------|
| **`admin_v2.move`** | Protocol governance & configuration | ✅ Active | Multi-sig governance, parameter validation, emergency controls |
| **`ledger_v2.move`** | Points accounting & economics | ✅ Active | Fixed APY calculations, supply tracking, overflow protection |
| **`partner_v3.move`** | Partner management & USDC vaults | ✅ Active | DeFi-compatible vaults, collateral management, yield integration |
| **`generation_manager_v2.move`** | Partner integration infrastructure | ✅ Active | Action registration, quota validation, webhook support |
| **`perk_manager_v2.move`** | Points redemption marketplace | ✅ Active | Oracle-based pricing, revenue distribution, USDC payouts |
| **`oracle_v2.move`** | Multi-source price feeds | ✅ Active | Pyth + CoinGecko, automated failover, price validation |
| **`integration_v2.move`** | User-facing entry points | ✅ Active | Simplified staking/lending, points redemption, safety checks |

### Legacy Modules (Disabled)

All `.disabled` modules are legacy V1 implementations kept for reference but not used in production.

---

## 🚀 Key Features

### 1. **Fixed Economic Model**
- **Correct APY Calculations**: Eliminated 223x multiplier bug from V1
- **Stable Conversion Rate**: 1 USD = 1,000 Alpha Points (fixed)
- **Supply Cap Protection**: Maximum 1 trillion points total supply
- **Daily Mint Limits**: Per-user and global limits prevent abuse

### 2. **USDC-Backed Partner System**
- **Stable Collateral**: USDC-only eliminates volatility risk
- **DeFi Integration**: Vaults can be transferred to yield protocols
- **Proportional Withdrawals**: Partners can withdraw unused collateral
- **Automated Backing**: Points minting requires sufficient vault backing

### 3. **Multi-Source Oracle System**
- **Primary**: Pyth Network (sub-second updates, enterprise-grade)
- **Backup**: CoinGecko API (30-second updates, reliable fallback)
- **Validation**: Cross-source price verification prevents manipulation
- **Staleness Protection**: Configurable freshness thresholds

### 4. **Enterprise Partner Integration**
- **Action Registration**: Partners define which actions mint points
- **Webhook Support**: Real-time notifications for partner systems
- **Quota Management**: Daily and lifetime minting limits per partner
- **Rate Limiting**: Prevents abuse with configurable windows

### 5. **Comprehensive Governance**
- **Multi-Signature**: Requires multiple signatures for critical changes
- **Timelock Mechanism**: Delays execution for security
- **Parameter Validation**: Bounds checking prevents extreme changes
- **Emergency Controls**: Pause functionality for different operations

---

## 💼 Business Logic

### Partner Onboarding Flow

1. **USDC Deposit**: Partners lock USDC as collateral in their vault
2. **Capability Creation**: Receive `PartnerCapV3` linked to their vault
3. **Action Registration**: Define actions in their system that mint points
4. **Integration**: Use webhooks/APIs to mint points when users complete actions
5. **Revenue Sharing**: Earn USDC revenue when users redeem perks

### Revenue Distribution Model

```
Perk Sale (100% of payment)
├── 70% → Perk Creator (immediate USDC payout)
├── 20% → Platform Treasury (protocol revenue)
└── 10% → Partner Vault Growth (increases backing capacity)
```

### Collateralization Requirements

- **Minimum Vault**: $100 USDC to create partner vault
- **Safety Buffer**: 110% collateralization required for point minting
- **DeFi Threshold**: $1,000 minimum to transfer vault to DeFi protocols
- **Yield Share**: 50% of DeFi yield goes to protocol, 50% to partner

---

## 🔧 Technical Implementation

### Core Data Structures

```move
// Partner vault with USDC collateral
public struct PartnerVault<phantom T> has key, store {
    id: UID,
    usdc_balance: Balance<T>,           // USDC collateral
    reserved_backing: u64,              // Points backing requirement
    available_balance: u64,             // Available for withdrawal
    total_points_minted: u64,           // Lifetime points minted
    defi_protocol: Option<String>,      // Current DeFi integration
    last_yield_harvest: u64,            // Last yield harvest timestamp
}

// Enhanced configuration with clear semantics
public struct ConfigV2 has key {
    apy_basis_points: u64,              // APY in basis points (500 = 5%)
    points_per_usd: u64,                // 1000 points per $1 USD
    max_total_supply: u64,              // Maximum points supply cap
    daily_mint_cap_global: u64,         // Global daily minting limit
    daily_mint_cap_per_user: u64,       // Per-user daily limit
    // ... additional governance and safety parameters
}
```

### Security Features

- **Overflow Protection**: All arithmetic operations use checked math
- **Access Control**: Capability-based permissions with ID validation
- **Parameter Bounds**: All configuration changes validated against limits
- **Emergency Pause**: Multiple pause types for different operations
- **Rate Limiting**: Configurable windows prevent spam attacks

---

## 🧪 Testing & Quality Assurance

### Test Coverage Status

- **`generation_manager_v2.move`**: ✅ 90%+ coverage achieved
- **`partner_v3.move`**: ✅ 95%+ coverage achieved
- **`admin_v2.move`**: ✅ Comprehensive test suite
- **`ledger_v2.move`**: ✅ Mathematical correctness verified
- **`oracle_v2.move`**: ✅ Failover scenarios tested
- **`perk_manager_v2.move`**: ✅ Revenue distribution verified

### Testing Strategy

1. **Unit Tests**: Individual function validation
2. **Integration Tests**: Cross-module interaction testing
3. **Error Case Coverage**: Comprehensive error condition testing
4. **Edge Case Validation**: Boundary value and overflow testing
5. **Economic Model Verification**: Mathematical correctness validation

---

## 🚀 Deployment & Operations

### Build Commands

```bash
# Build the package
sui move build

# Run tests with coverage
sui move test --coverage

# Run specific test module
sui move test --filter partner_v3

# Check for linting issues
sui move lint
```

### Environment Configuration

The protocol supports both testnet and mainnet deployments with configurable USDC addresses:

- **Testnet USDC**: `0xa1ec7fc00a6f40db9693ad1415d0c193ad3906494428cf252621037bd7117e29::usdc::USDC`
- **Mainnet USDC**: `0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC`

---

## 📖 Integration Guide

### For New Partners

1. **Deposit Collateral**: Use `create_partner_with_usdc_vault()` to deposit USDC
2. **Register Actions**: Define actions via `register_action()` in generation_manager_v2
3. **Implement Webhooks**: Set up endpoints to receive minting notifications
4. **Mint Points**: Call `execute_registered_action()` when users complete actions
5. **Create Perks**: Use perk_manager_v2 to offer redemption opportunities

### For DeFi Protocols

1. **Vault Integration**: Accept `PartnerVault` objects as collateral
2. **Yield Reporting**: Implement `harvest_defi_yield()` callback
3. **Health Monitoring**: Respect collateralization requirements
4. **Emergency Handling**: Support vault withdrawal for liquidations

---

## ⚠️ Important Notes

### Upgrade Safety

This package follows Sui Move upgrade compatibility requirements:

- ✅ **Struct Compatibility**: No changes to existing struct layouts
- ✅ **Function Signatures**: All public functions maintain signatures
- ✅ **Deprecation Strategy**: Old functions marked deprecated but functional
- ✅ **Migration Support**: Clear upgrade path from V1 to V2

### Security Considerations

- **Private Key Management**: Secure storage of admin capabilities required
- **Oracle Dependencies**: Monitor Pyth Network and CoinGecko availability
- **Collateral Monitoring**: Regular health checks for partner vaults
- **Emergency Procedures**: Documented processes for pause/unpause operations

---

## 📞 Support & Documentation

### Development Resources

- **Frontend Integration**: See `/frontend/README.md` for UI implementation
- **API Documentation**: Generated from Move docstrings
- **Test Examples**: Comprehensive test files demonstrate usage patterns
- **Error Codes**: Detailed error constants with explanations

### Community & Support

- **Issues**: Report bugs via GitHub issues
- **Discussions**: Technical discussions in GitHub discussions
- **Updates**: Protocol updates announced via official channels

---

## 📄 License & Contributing

This project is part of the Alpha Points ecosystem. Please review contribution guidelines and licensing terms before submitting changes.

**Last Updated**: December 2024  
**Protocol Version**: 2.0  
**Sui Compatibility**: Latest stable release 