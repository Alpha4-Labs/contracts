# Ledger Simple Module Specification

## 🎯 Purpose
Core point accounting system with mint/burn operations and balance tracking. Removes all staking/reward calculation complexity.

## 📦 Current vs Simplified

**REMOVE (860 lines):**
- ❌ APY reward calculations (complex 128-bit math)
- ❌ Time-based reward accrual
- ❌ Staking position integration
- ❌ Complex daily reset logic
- ❌ Multi-tier user balance system
- ❌ SUI-to-USD conversion functions
- ❌ Loan collateral tracking
- ❌ Advanced economic calculation functions

**KEEP (400 lines):**
- ✅ Basic point minting/burning
- ✅ User balance tracking
- ✅ Supply cap controls
- ✅ Daily mint limits
- ✅ Point type categorization
- ✅ Emergency pause integration

## 🏗️ Core Structures

```move
/// Simplified ledger - pure accounting, no rewards
public struct LedgerSimple has key {
    id: UID,
    
    // Supply tracking
    total_points_minted: u64,
    total_points_burned: u64,
    
    // User balances (simplified)
    balances: Table<address, u64>,     // Simple balance mapping
    
    // Risk management
    max_total_supply: u64,             // 1 trillion points max
    daily_mint_cap_global: u64,        // Global daily limit
    daily_minted_today: u64,           // Today's minted amount
    last_reset_day: u64,               // Last daily reset
    
    // Admin reference
    admin_cap_id: ID,
}

/// Simple point type for tracking
public enum PointType has copy, drop {
    PartnerReward,      // Points from partner actions
    PerkRedemption,     // Points used for perk redemption  
    AdminMint,          // Admin-minted points
}
```

## 🔧 Essential Functions

```move
// Core operations (used by other modules)
public fun mint_points(
    ledger: &mut LedgerSimple,
    user: address, 
    amount: u64,
    point_type: PointType,
    ctx: &mut TxContext
)

public fun burn_points(
    ledger: &mut LedgerSimple,
    user: address,
    amount: u64,
    point_type: PointType,
    ctx: &mut TxContext  
)

// Balance queries (used by other modules)
public fun get_balance(ledger: &LedgerSimple, user: address): u64
public fun get_total_supply(ledger: &LedgerSimple): u64

// Supply validation (internal)
fun check_supply_limits(ledger: &LedgerSimple, mint_amount: u64)
fun reset_daily_limits_if_needed(ledger: &mut LedgerSimple)
```

## 🔗 Dependencies
- **Imports:** admin_simple (for pause controls)
- **Used by:** partner_simple, perk_simple, integration_simple, generation_simple

## ⚡ Complexity Reduction
- **Lines:** 1,260 → 400 (68% reduction)
- **Functions:** 20+ → 8 (60% reduction)
- **Audit Weight:** 12,600 → 2,000 equivalent lines (84% reduction)

## 🛡️ Security Notes
- No complex math = no calculation bugs
- Simple supply caps = basic economic protection  
- Daily limits = abuse prevention
- Pure accounting model = clear audit scope
- Removed APY calculations = eliminated 223x multiplier bug class
