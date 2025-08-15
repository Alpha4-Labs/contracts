# Oracle Simple Module Specification

## 🎯 Purpose
Basic price feed system for perk pricing. Simplified oracle without complex validation and failover mechanisms.

## 📦 Current vs Simplified

**REMOVE (239 lines):**
- ❌ Multi-source price validation
- ❌ Complex failover mechanisms
- ❌ Advanced rate limiting systems
- ❌ Cross-source price comparison
- ❌ Health monitoring and analytics
- ❌ Pyth Network integration complexity
- ❌ CoinGecko API integration
- ❌ Advanced staleness protection

**KEEP (250 lines):**
- ✅ Basic price feed storage
- ✅ Price update functionality
- ✅ Freshness validation
- ✅ Simple confidence checks
- ✅ Emergency pause integration
- ✅ Basic SUI/USD and USDC/USD feeds

## 🏗️ Core Structures

```move
/// Simplified price data - essential fields only
public struct PriceDataSimple has store, copy {
    price: u64,                       // Price with 8 decimal precision
    confidence: u64,                  // Confidence score (basis points)
    timestamp_ms: u64,                // Last update time
    is_stale: bool,                   // Staleness flag
}

/// Simple oracle - basic price feeds only
public struct OracleSimple has key {
    id: UID,
    
    // Price feeds
    current_prices: Table<String, PriceDataSimple>, // trading_pair -> price
    
    // Configuration
    max_staleness_ms: u64,            // 1 hour default
    min_confidence: u64,              // 80% minimum confidence
    
    // Controls
    is_paused: bool,
    admin_cap_id: ID,
    
    // Basic stats
    total_updates: u64,
    last_update_ms: u64,
}

/// Simple oracle capability
public struct OracleCapSimple has key, store {
    id: UID,
    oracle_id: ID,
    can_update_prices: bool,
}
```

## 🔧 Essential Functions

```move
// Price updates (external integration)
public entry fun update_price(
    oracle: &mut OracleSimple,
    oracle_cap: &OracleCapSimple,
    trading_pair: String,
    price: u64,
    confidence: u64,
    ctx: &mut TxContext
)

// Price queries (used by perk_simple)
public fun get_price(oracle: &OracleSimple, trading_pair: String): u64
public fun is_price_fresh(oracle: &OracleSimple, trading_pair: String): bool
public fun get_price_with_confidence(oracle: &OracleSimple, trading_pair: String): (u64, u64)

// Validation (internal)
fun validate_price_freshness(oracle: &OracleSimple, trading_pair: String, current_time: u64): bool
fun validate_price_confidence(price_data: &PriceDataSimple, min_confidence: u64): bool

// Admin functions
public entry fun set_staleness_threshold(oracle: &mut OracleSimple, oracle_cap: &OracleCapSimple, new_threshold: u64)
public entry fun emergency_pause(oracle: &mut OracleSimple, oracle_cap: &OracleCapSimple, paused: bool)
```

## 🔗 Dependencies
- **Imports:** admin_simple (for pause controls)
- **Used by:** perk_simple (for USDC pricing)

## ⚡ Complexity Reduction
- **Lines:** 489 → 250 (49% reduction)
- **Functions:** 15+ → 8 (47% reduction)
- **Audit Weight:** 2,934 → 500 equivalent lines (83% reduction)

## 🛡️ Security Notes
- Basic price validation sufficient for perk pricing
- Staleness protection prevents old price usage
- Confidence checks ensure price quality
- Emergency pause for oracle failures
- Removed complex failover = simpler attack surface
- Single price source = easier to audit and maintain
