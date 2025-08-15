# Perk Simple Module Specification

## 🎯 Purpose
Perk marketplace with creation, redemption, and USDC revenue distribution. Core monetization system for B2B platform.

## 📦 Current vs Simplified

**REMOVE (452 lines):**
- ❌ Complex perk lifecycle management
- ❌ Advanced analytics and health scoring
- ❌ Geographic restrictions and compliance
- ❌ Content rating systems
- ❌ Webhook delivery systems
- ❌ Complex claim validation chains
- ❌ Advanced metadata management
- ❌ Marketplace curation features

**KEEP (800 lines):**
- ✅ Perk creation by partners
- ✅ USDC-based pricing with oracle integration
- ✅ Point redemption for perks
- ✅ Revenue distribution (partner/platform splits)
- ✅ Basic claim limits and validation
- ✅ Essential marketplace functionality

## 🏗️ Core Structures

```move
/// Simplified perk definition - core marketplace features only
public struct PerkSimple has key, store {
    id: UID,
    
    // Perk identity
    name: String,
    description: String,
    category: String,                  // "gaming", "rewards", "discounts"
    
    // Partner ownership
    creator_partner_cap_id: ID,
    partner_vault_id: ID,
    
    // Pricing (core business logic)
    base_price_usdc: u64,             // Price in USDC (6 decimals)
    current_price_points: u64,        // Current price in points (oracle-based)
    partner_share_bps: u64,           // Partner revenue share (e.g., 7000 = 70%)
    
    // Availability
    is_active: bool,
    max_total_claims: Option<u64>,    // Optional claim limit
    total_claims_count: u64,
    
    // Revenue tracking
    total_revenue_usdc: u64,
    partner_revenue_usdc: u64,
    platform_revenue_usdc: u64,
}

/// Simplified claimed perk - essential tracking only
public struct ClaimedPerkSimple has key, store {
    id: UID,
    perk_id: ID,
    claimer_address: address,
    points_spent: u64,
    usdc_value: u64,
    claim_timestamp_ms: u64,
    status: String,                   // "pending", "fulfilled", "expired"
}

/// Simple marketplace registry
public struct PerkMarketplaceSimple has key {
    id: UID,
    
    // Perk organization
    active_perks: vector<ID>,
    perks_by_partner: Table<ID, vector<ID>>,
    
    // Revenue tracking
    total_perks_created: u64,
    total_perks_claimed: u64,
    total_revenue_distributed: u64,
    
    // Controls
    is_paused: bool,
    admin_cap_id: ID,
}
```

## 🔧 Essential Functions

```move
// Perk creation (core partner function)
public entry fun create_perk(
    marketplace: &mut PerkMarketplaceSimple,
    partner_cap: &PartnerCapSimple,
    partner_vault: &PartnerVaultSimple,
    name: String,
    description: String,
    category: String,
    base_price_usdc: u64,
    partner_share_bps: u64,
    max_claims: Option<u64>,
    ctx: &mut TxContext
) -> PerkSimple

// Perk redemption (core user function)  
public entry fun claim_perk(
    marketplace: &mut PerkMarketplaceSimple,
    perk: &mut PerkSimple,
    partner_vault: &mut PartnerVaultSimple,
    ledger: &mut LedgerSimple,
    oracle: &OracleSimple,
    ctx: &mut TxContext
) -> ClaimedPerkSimple

// Price updates (oracle integration)
public fun update_perk_price(
    perk: &mut PerkSimple,
    oracle: &OracleSimple
)

// Revenue distribution (core business logic)
fun distribute_revenue(
    perk: &mut PerkSimple,
    partner_vault: &mut PartnerVaultSimple,
    total_usdc: u64
)

// View functions
public fun get_perk_info(perk: &PerkSimple): (String, u64, u64, bool) // (name, usdc_price, points_price, active)
public fun get_marketplace_stats(marketplace: &PerkMarketplaceSimple): (u64, u64, u64) // (total_perks, claims, revenue)
```

## 🔗 Dependencies
- **Imports:** admin_simple, ledger_simple, partner_simple, oracle_simple
- **Used by:** integration_simple (optional perk integration)

## ⚡ Complexity Reduction
- **Lines:** 1,252 → 800 (36% reduction)
- **Functions:** 25+ → 12 (52% reduction)
- **Audit Weight:** 7,512 → 2,400 equivalent lines (68% reduction)

## 🛡️ Security Notes
- Core revenue distribution math preserved
- Oracle price integration maintained for security
- Simplified claim validation reduces edge cases
- Direct USDC distribution = clear financial flows
- Removed complex marketplace features = focused audit scope
