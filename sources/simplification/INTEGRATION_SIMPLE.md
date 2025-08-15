# Integration Simple Module Specification

## 🎯 Purpose
Basic user interaction endpoints for B2B platform. Simplified interface removing all staking/loan complexity.

## 📦 Current vs Simplified

**REMOVE (99 lines):**
- ❌ Staking functionality (stake_sui_for_points)
- ❌ Unstaking functionality (request_unstake)
- ❌ Loan functionality (liquid_unstake_as_loan)
- ❌ Complex economic model fixes
- ❌ APY-based reward calculations
- ❌ Time-based staking positions
- ❌ SUI collateral management
- ❌ Double reward system fixes

**KEEP (100 lines):**
- ✅ Basic point redemption for USDC
- ✅ Simple user interaction endpoints
- ✅ Integration with core modules
- ✅ Emergency pause integration
- ✅ Basic validation and safety checks

## 🏗️ Core Structures

```move
/// Simple user interaction events
public struct PointsRedeemed has copy, drop {
    user: address,
    points_amount: u64,
    usdc_received: u64,
    fee_paid: u64,
    timestamp_ms: u64,
}

public struct UserAction has copy, drop {
    user: address,
    action_type: String,
    points_involved: u64,
    timestamp_ms: u64,
}
```

## 🔧 Essential Functions

```move
// Point redemption (core user function)
public entry fun redeem_points_for_usdc(
    config: &ConfigSimple,
    ledger: &mut LedgerSimple,
    oracle: &OracleSimple,
    user_points_amount: u64,
    ctx: &mut TxContext
) -> Coin<USDC>

// Basic user queries
public fun get_user_balance(ledger: &LedgerSimple, user: address): u64
public fun calculate_redemption_value(
    oracle: &OracleSimple,
    points_amount: u64
): (u64, u64) // (usdc_value, fee_amount)

// Internal helpers
fun calculate_redemption_fee(usdc_amount: u64): u64
fun validate_redemption_amount(points_amount: u64): bool
```

## 🔗 Dependencies
- **Imports:** admin_simple, ledger_simple, oracle_simple
- **Used by:** Frontend applications, partner integrations (optional)

## ⚡ Complexity Reduction
- **Lines:** 199 → 100 (50% reduction)
- **Functions:** 8+ → 4 (50% reduction)
- **Audit Weight:** 398 → 200 equivalent lines (50% reduction)

## 🛡️ Security Notes
- Removed all staking/loan attack vectors
- Simple redemption logic = clear audit scope
- No time-based calculations = no timing attacks
- Basic USDC redemption = straightforward financial flow
- Eliminated double reward bugs by removing staking entirely
