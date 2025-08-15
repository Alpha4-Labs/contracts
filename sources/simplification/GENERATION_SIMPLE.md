# Generation Simple Module Specification

## 🎯 Purpose
Partner integration system for B2B platform. Essential endpoints for partners to mint points when users complete actions.

## 📦 Current vs Simplified

**REMOVE (683 lines):**
- ❌ Complex webhook delivery systems
- ❌ Advanced rate limiting and analytics
- ❌ Health monitoring and trending analysis
- ❌ Complex integration approval workflows
- ❌ Advanced API key management
- ❌ Detailed audit trail systems
- ❌ Geographic restrictions and compliance
- ❌ Advanced partner statistics and monitoring

**KEEP (600 lines):**
- ✅ Partner integration registration
- ✅ Action registration (define point-earning actions)
- ✅ Action execution endpoint (core integration function)
- ✅ Basic rate limiting and quotas
- ✅ Simple API key authentication
- ✅ Essential partner management

## 🏗️ Core Structures

```move
/// Simplified partner integration - core B2B features only
public struct PartnerIntegrationSimple has key, store {
    id: UID,
    
    // Integration identity
    integration_name: String,
    partner_cap_id: ID,
    partner_address: address,
    
    // Authentication
    api_key: vector<u8>,              // Simple API key
    api_key_created_ms: u64,
    
    // Action registry
    registered_actions: Table<String, ID>, // action_name -> RegisteredAction ID
    active_actions_count: u64,
    
    // Basic rate limiting
    requests_this_hour: u64,
    hour_window_start_ms: u64,
    max_requests_per_hour: u64,       // Simple hourly limit
    
    // Status
    is_active: bool,
    is_approved: bool,                // Simple approval flag
    
    // Basic stats
    total_executions: u64,
    total_points_minted: u64,
}

/// Simplified registered action - core point-earning actions
public struct RegisteredActionSimple has key, store {
    id: UID,
    
    // Action identity
    action_name: String,              // e.g., "level_completed", "purchase_made"
    display_name: String,
    category: String,                 // "gaming", "ecommerce", "social"
    
    // Partner ownership
    partner_cap_id: ID,
    partner_address: address,
    
    // Point configuration (core business logic)
    points_per_execution: u64,        // Points minted per action
    max_daily_executions: Option<u64>, // Optional daily limit
    
    // Execution tracking
    total_executions: u64,
    daily_executions: u64,
    last_daily_reset_ms: u64,
    
    // Status
    is_active: bool,
}

/// Simple integration registry
public struct IntegrationRegistrySimple has key {
    id: UID,
    
    // Registry organization
    integrations_by_partner: Table<ID, ID>, // PartnerCap -> Integration ID
    active_integrations: vector<ID>,
    
    // Global stats
    total_integrations: u64,
    total_actions: u64,
    total_executions: u64,
    
    // Controls
    is_paused: bool,
    admin_cap_id: ID,
}
```

## 🔧 Essential Functions

```move
// Partner integration registration (B2B onboarding)
public entry fun register_partner_integration(
    registry: &mut IntegrationRegistrySimple,
    partner_cap: &PartnerCapSimple,
    partner_vault: &PartnerVaultSimple,
    integration_name: String,
    ctx: &mut TxContext
) -> PartnerIntegrationSimple

// Action registration (define point-earning actions)
public entry fun register_action(
    registry: &mut IntegrationRegistrySimple,
    integration: &mut PartnerIntegrationSimple,
    partner_cap: &PartnerCapSimple,
    action_name: String,
    display_name: String,
    category: String,
    points_per_execution: u64,
    max_daily_executions: Option<u64>,
    ctx: &mut TxContext
) -> RegisteredActionSimple

// Action execution (CORE INTEGRATION FUNCTION)
public entry fun execute_registered_action(
    registry: &mut IntegrationRegistrySimple,
    integration: &mut PartnerIntegrationSimple,
    action: &mut RegisteredActionSimple,
    partner_cap: &PartnerCapSimple,
    partner_vault: &mut PartnerVaultSimple,
    ledger: &mut LedgerSimple,
    user_address: address,
    ctx: &mut TxContext
)

// Rate limiting (internal)
fun check_rate_limits(integration: &mut PartnerIntegrationSimple, current_time: u64)
fun reset_daily_counters(action: &mut RegisteredActionSimple, current_time: u64)

// View functions
public fun get_integration_info(integration: &PartnerIntegrationSimple): (String, bool, u64)
public fun get_action_info(action: &RegisteredActionSimple): (String, u64, u64, bool)
public fun can_execute_action(action: &RegisteredActionSimple): bool
```

## 🔗 Dependencies
- **Imports:** admin_simple, ledger_simple, partner_simple
- **Used by:** External partner applications (via API/SDK)

## ⚡ Complexity Reduction
- **Lines:** 1,283 → 600 (53% reduction)
- **Functions:** 20+ → 10 (50% reduction)
- **Audit Weight:** 5,132 → 1,800 equivalent lines (65% reduction)

## 🛡️ Security Notes
- Core action execution logic preserved
- Simplified rate limiting reduces complexity
- Basic API key authentication sufficient for B2B
- Direct partner vault integration maintains financial controls
- Removed complex analytics = focused security audit
