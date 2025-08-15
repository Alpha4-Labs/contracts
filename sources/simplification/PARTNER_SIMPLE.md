# Partner Simple Module Specification

## 🎯 Purpose
USDC vault management and partner onboarding system. Core business logic for B2B platform without DeFi complexity.

## 📦 Current vs Simplified

**REMOVE (234 lines):**
- ❌ DeFi protocol integration
- ❌ Yield generation/harvesting
- ❌ Complex health factor calculations
- ❌ Advanced vault analytics
- ❌ Generation-based partner grouping
- ❌ Time-based quota resets
- ❌ Vault transferability to DeFi protocols

**KEEP (300 lines):**
- ✅ USDC vault creation
- ✅ Partner capability management
- ✅ Quota allocation based on USDC
- ✅ Point minting with backing validation
- ✅ USDC withdrawal with safety checks
- ✅ Basic vault health monitoring

## 🏗️ Core Structures

```move
/// Simplified partner vault - USDC backing only
public struct PartnerVaultSimple has key, store {
    id: UID,
    
    // Vault identity
    partner_address: address,
    vault_name: String,
    created_timestamp_ms: u64,
    
    // USDC management (core business logic)
    usdc_balance: Balance<USDC>,       // USDC holdings
    reserved_for_backing: u64,         // USDC reserved for points
    available_for_withdrawal: u64,     // USDC available to partner
    
    // Quota tracking (simplified)
    lifetime_quota_points: u64,        // Total quota from USDC deposit
    outstanding_points_minted: u64,    // Points currently backed by vault
    
    // Status
    is_active: bool,
    is_locked: bool,                   // Emergency lock
}

/// Simplified partner capability
public struct PartnerCapSimple has key, store {
    id: UID,
    partner_address: address,
    vault_id: ID,                      // Associated vault
    
    // Simple quota tracking
    daily_quota_points: u64,           // Daily minting limit
    daily_quota_used: u64,             // Used today
    last_quota_reset_day: u64,         // Last reset
    
    // Status
    is_active: bool,
    is_paused: bool,
}
```

## 🔧 Essential Functions

```move
// Partner onboarding (core B2B function)
public entry fun create_partner_and_vault(
    config: &ConfigSimple,
    partner_name: String,
    vault_name: String,
    usdc_collateral: Coin<USDC>,
    ctx: &mut TxContext
) -> (PartnerCapSimple, PartnerVaultSimple)

// Quota utilization (core integration function)
public entry fun mint_points_against_quota(
    config: &ConfigSimple,
    partner_cap: &mut PartnerCapSimple,
    vault: &mut PartnerVaultSimple,
    ledger: &mut LedgerSimple,
    user_address: address,
    points_amount: u64,
    ctx: &mut TxContext
)

// USDC management (core financial function)
public entry fun withdraw_usdc_from_vault(
    config: &ConfigSimple,
    partner_cap: &PartnerCapSimple,
    vault: &mut PartnerVaultSimple,
    withdrawal_amount: u64,
    ctx: &mut TxContext
) -> Coin<USDC>

// View functions
public fun get_vault_info(vault: &PartnerVaultSimple): (u64, u64, u64) // (total_usdc, reserved, available)
public fun get_quota_info(cap: &PartnerCapSimple): (u64, u64) // (daily_quota, used)
public fun can_mint_points(vault: &PartnerVaultSimple, amount: u64): bool
```

## 🔗 Dependencies
- **Imports:** admin_simple, ledger_simple
- **Used by:** perk_simple, integration_simple, generation_simple

## ⚡ Complexity Reduction
- **Lines:** 534 → 300 (44% reduction)
- **Functions:** 15+ → 8 (47% reduction)
- **Audit Weight:** 5,340 → 1,500 equivalent lines (72% reduction)

## 🛡️ Security Notes
- Core USDC backing math preserved
- Simplified quota system reduces attack surface
- No DeFi integration = no yield farming risks
- Direct USDC withdrawal validation = clear financial controls
- Removed complex health calculations = fewer edge cases
