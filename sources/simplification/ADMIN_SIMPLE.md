# Admin Simple Module Specification

## 🎯 Purpose
Minimal admin module providing only essential configuration and emergency controls for B2B platform.

## 📦 Current vs Simplified

**REMOVE (844 lines):**
- ❌ Multi-sig governance system
- ❌ Proposal creation/voting/execution  
- ❌ Timelock mechanisms
- ❌ Complex parameter validation
- ❌ APY rate management
- ❌ Grace period management
- ❌ Economic limits updating
- ❌ Advanced emergency controls

**KEEP (150 lines):**
- ✅ Basic configuration struct
- ✅ Admin capability
- ✅ Emergency pause controls
- ✅ Treasury address management
- ✅ Points-per-USD ratio (fixed)

## 🏗️ Core Structures

```move
/// Simplified configuration - B2B platform essentials only
public struct ConfigSimple has key {
    id: UID,
    
    // Economic parameters (FIXED - no governance needed)
    points_per_usd: u64,           // Fixed: 1000 points per $1 USD
    treasury_address: address,      // Platform treasury for revenue
    
    // Emergency controls (simple boolean flags)
    emergency_pause: bool,          // Global emergency pause
    mint_pause: bool,              // Pause point minting
    
    // Metadata
    last_updated_by: address,       // Last admin who made changes
}

/// Simple admin capability - no complex permissions
public struct AdminCapSimple has key, store {
    id: UID,
    created_for: address,          // Admin address
}
```

## 🔧 Essential Functions

```move
// View functions (used by other modules)
public fun get_points_per_usd(config: &ConfigSimple): u64
public fun get_treasury_address(): address  
public fun is_paused(config: &ConfigSimple): bool

// Safety assertions (used by other modules)
public fun assert_not_paused(config: &ConfigSimple)
public fun assert_mint_not_paused(config: &ConfigSimple)

// Authorization (used by other modules)
public fun is_admin(admin_cap: &AdminCapSimple, config: &ConfigSimple): bool

// Admin functions (simple, no governance)
public entry fun set_emergency_pause(config: &mut ConfigSimple, admin_cap: &AdminCapSimple, paused: bool)
public entry fun set_treasury_address(config: &mut ConfigSimple, admin_cap: &AdminCapSimple, new_address: address)
```

## 🔗 Dependencies
- **Imports:** Standard Sui modules only
- **Used by:** ALL other modules for configuration and pause controls

## ⚡ Complexity Reduction
- **Lines:** 994 → 150 (85% reduction)
- **Functions:** 25+ → 8 (68% reduction)  
- **Audit Weight:** 6,958 → 300 equivalent lines (96% reduction)

## 🛡️ Security Notes
- No governance = no governance attacks
- Fixed economic parameters = no parameter manipulation
- Simple pause controls = sufficient emergency response
- Single admin model = appropriate for B2B platform
