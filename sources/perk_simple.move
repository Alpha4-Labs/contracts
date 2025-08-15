#[allow(duplicate_alias, unused_use)]
/// Simplified Perk Module - Core Marketplace Functionality
/// 
/// Core Features:
/// 1. PERK CREATION - Partners create redeemable perks with USDC pricing
/// 2. POINT REDEMPTION - Users spend points for perks
/// 3. REVENUE DISTRIBUTION - USDC flows to partners from redemptions
/// 4. ORACLE INTEGRATION - Real-time pricing via oracle_simple
/// 5. REMOVED COMPLEXITY - No advanced analytics, curation, or complex lifecycle management
module alpha_points::perk_simple {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use std::string::{Self, String};
    use std::option::Option;
    
    // Import simplified modules
    use alpha_points::admin_simple::{Self, ConfigSimple, AdminCapSimple};
    use alpha_points::ledger_simple::{Self, LedgerSimple};
    use alpha_points::partner_simple::{Self, PartnerCapSimple, PartnerVaultSimple};
    use alpha_points::oracle_simple::{Self, OracleSimple};
    
    // USDC Type
    public struct USDC has drop {}
    
    // =================== CONSTANTS ===================
    
    const MAX_PERK_NAME_LENGTH: u64 = 200;
    const MAX_PERK_DESCRIPTION_LENGTH: u64 = 2000;
    const MIN_PERK_PRICE_USDC: u64 = 1000000;          // $1.00 minimum (6 decimals)
    const MAX_PERK_PRICE_USDC: u64 = 1000000000000;    // $1M maximum
    const REVENUE_SPLIT_PRECISION: u64 = 10000;        // 10000 basis points = 100%
    const MIN_PARTNER_SHARE_BPS: u64 = 5000;           // 50% minimum partner share
    const MAX_PARTNER_SHARE_BPS: u64 = 9000;           // 90% maximum partner share
    const MINIMUM_ORACLE_CONFIDENCE: u64 = 8000;       // 80% minimum confidence
    
    // =================== ERROR CONSTANTS ===================
    
    const EUnauthorized: u64 = 1;
    const EPerkNotActive: u64 = 2;
    const EInsufficientPoints: u64 = 3;
    const EMaxClaimsReached: u64 = 4;
    const EInvalidPerkName: u64 = 5;
    const EInvalidPerkPrice: u64 = 6;
    const EInvalidRevenueSplit: u64 = 7;
    const EEmergencyPaused: u64 = 8;
    const EOracleDataStale: u64 = 9;
    const EInsufficientOracleConfidence: u64 = 10;
    #[allow(unused_const)]
    const EPerkExpired: u64 = 11;
    
    // =================== STRUCTS ===================
    
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
        
        // Timestamps
        created_timestamp_ms: u64,
        last_price_update_ms: u64,
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
    
    // =================== EVENTS ===================
    
    public struct PerkCreated has copy, drop {
        perk_id: ID,
        creator_partner_cap_id: ID,
        name: String,
        category: String,
        base_price_usdc: u64,
        partner_share_bps: u64,
        timestamp_ms: u64,
    }
    
    public struct PerkClaimed has copy, drop {
        claimed_perk_id: ID,
        perk_id: ID,
        claimer_address: address,
        points_spent: u64,
        usdc_value: u64,
        partner_revenue_usdc: u64,
        platform_revenue_usdc: u64,
        timestamp_ms: u64,
    }
    
    public struct PerkPriceUpdated has copy, drop {
        perk_id: ID,
        old_price_points: u64,
        new_price_points: u64,
        oracle_confidence: u64,
        timestamp_ms: u64,
    }
    
    // =================== INITIALIZATION ===================
    
    fun init(_ctx: &mut TxContext) {
        // Marketplace should be created via create_perk_marketplace_simple
    }
    
    /// Create perk marketplace
    public entry fun create_perk_marketplace_simple(
        config: &ConfigSimple,
        admin_cap: &AdminCapSimple,
        ctx: &mut TxContext
    ) {
        assert!(admin_simple::is_admin(admin_cap, config), EUnauthorized);
        
        let marketplace = PerkMarketplaceSimple {
            id: object::new(ctx),
            active_perks: vector::empty(),
            perks_by_partner: table::new(ctx),
            total_perks_created: 0,
            total_perks_claimed: 0,
            total_revenue_distributed: 0,
            is_paused: false,
            admin_cap_id: admin_simple::get_admin_cap_id(admin_cap),
        };
        
        transfer::share_object(marketplace);
    }
    
    // =================== CORE FUNCTIONS ===================
    
    /// Perk creation (core partner function)
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
        oracle: &OracleSimple,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate marketplace state
        assert!(!marketplace.is_paused, EEmergencyPaused);
        
        let creator_address = tx_context::sender(ctx);
        let current_time_ms = clock::timestamp_ms(clock);
        
        // Validate partner authorization
        assert!(partner_simple::get_partner_address(partner_cap) == creator_address, EUnauthorized);
        assert!(!partner_simple::is_paused(partner_cap), EEmergencyPaused);
        assert!(partner_simple::get_vault_partner_address(partner_vault) == creator_address, EUnauthorized);
        
        // Input validation
        assert!(string::length(&name) > 0 && string::length(&name) <= MAX_PERK_NAME_LENGTH, EInvalidPerkName);
        assert!(string::length(&description) <= MAX_PERK_DESCRIPTION_LENGTH, EInvalidPerkName);
        assert!(base_price_usdc >= MIN_PERK_PRICE_USDC && base_price_usdc <= MAX_PERK_PRICE_USDC, EInvalidPerkPrice);
        assert!(partner_share_bps >= MIN_PARTNER_SHARE_BPS && partner_share_bps <= MAX_PARTNER_SHARE_BPS, EInvalidRevenueSplit);
        
        // Calculate initial points price using oracle
        let sui_usd_price = oracle_simple::get_price(oracle, string::utf8(b"SUI/USD"));
        let initial_points_price = (base_price_usdc * 100000000) / sui_usd_price; // Convert USDC to points via SUI price
        
        // Create perk definition
        let perk = PerkSimple {
            id: object::new(ctx),
            name,
            description,
            category,
            creator_partner_cap_id: partner_simple::get_partner_cap_uid_to_inner(partner_cap),
            partner_vault_id: partner_simple::get_partner_vault_uid_to_inner(partner_vault),
            base_price_usdc,
            current_price_points: initial_points_price,
            partner_share_bps,
            is_active: true,
            max_total_claims: max_claims,
            total_claims_count: 0,
            total_revenue_usdc: 0,
            partner_revenue_usdc: 0,
            platform_revenue_usdc: 0,
            created_timestamp_ms: current_time_ms,
            last_price_update_ms: current_time_ms,
        };
        
        let perk_id = object::uid_to_inner(&perk.id);
        let partner_cap_id = perk.creator_partner_cap_id;
        let perk_name_copy = perk.name;
        let perk_category_copy = perk.category;
        
        // Update marketplace
        vector::push_back(&mut marketplace.active_perks, perk_id);
        
        if (!table::contains(&marketplace.perks_by_partner, partner_cap_id)) {
            table::add(&mut marketplace.perks_by_partner, partner_cap_id, vector::empty());
        };
        let partner_perks = table::borrow_mut(&mut marketplace.perks_by_partner, partner_cap_id);
        vector::push_back(partner_perks, perk_id);
        
        marketplace.total_perks_created = marketplace.total_perks_created + 1;
        
        // Transfer perk to creator
        transfer::public_transfer(perk, creator_address);
        
        // Emit creation event
        event::emit(PerkCreated {
            perk_id,
            creator_partner_cap_id: partner_cap_id,
            name: perk_name_copy,
            category: perk_category_copy,
            base_price_usdc,
            partner_share_bps,
            timestamp_ms: current_time_ms,
        });
    }
    
    /// Perk redemption (core user function)  
    public entry fun claim_perk(
        marketplace: &mut PerkMarketplaceSimple,
        perk: &mut PerkSimple,
        _partner_vault: &mut PartnerVaultSimple,
        ledger: &mut LedgerSimple,
        config: &ConfigSimple,
        oracle: &OracleSimple,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate marketplace and perk state
        assert!(!marketplace.is_paused, EEmergencyPaused);
        assert!(perk.is_active, EPerkNotActive);
        
        let claimer_address = tx_context::sender(ctx);
        let current_time_ms = clock::timestamp_ms(clock);
        
        // Check claim limits
        if (option::is_some(&perk.max_total_claims)) {
            assert!(perk.total_claims_count < *option::borrow(&perk.max_total_claims), EMaxClaimsReached);
        };
        
        // Update perk price from oracle if needed
        if (should_update_price(perk, current_time_ms)) {
            update_perk_price_from_oracle(perk, oracle, current_time_ms);
        };
        
        let points_cost = perk.current_price_points;
        let usdc_value = perk.base_price_usdc;
        
        // Validate oracle data freshness and confidence
        assert!(oracle_simple::is_price_fresh(oracle, string::utf8(b"SUI/USD"), current_time_ms), EOracleDataStale);
        let (_, oracle_confidence) = oracle_simple::get_price_with_confidence(oracle, string::utf8(b"SUI/USD"));
        assert!(oracle_confidence >= MINIMUM_ORACLE_CONFIDENCE, EInsufficientOracleConfidence);
        
        // Check user has sufficient points
        let user_balance = ledger_simple::get_balance(ledger, claimer_address);
        assert!(user_balance >= points_cost, EInsufficientPoints);
        
        // Calculate revenue splits
        let partner_revenue_usdc = (usdc_value * perk.partner_share_bps) / REVENUE_SPLIT_PRECISION;
        let platform_revenue_usdc = usdc_value - partner_revenue_usdc;
        
        // Burn user points
        ledger_simple::burn_points(
            ledger,
            config,
            claimer_address,
            points_cost,
            ledger_simple::perk_redemption_type(),
            clock,
            ctx
        );
        
        // Create claimed perk
        let claimed_perk = ClaimedPerkSimple {
            id: object::new(ctx),
            perk_id: object::uid_to_inner(&perk.id),
            claimer_address,
            points_spent: points_cost,
            usdc_value,
            claim_timestamp_ms: current_time_ms,
            status: string::utf8(b"pending"),
        };
        
        let claimed_perk_id = object::uid_to_inner(&claimed_perk.id);
        
        // Update perk statistics
        perk.total_claims_count = perk.total_claims_count + 1;
        perk.total_revenue_usdc = perk.total_revenue_usdc + usdc_value;
        perk.partner_revenue_usdc = perk.partner_revenue_usdc + partner_revenue_usdc;
        perk.platform_revenue_usdc = perk.platform_revenue_usdc + platform_revenue_usdc;
        
        // Update marketplace statistics
        marketplace.total_perks_claimed = marketplace.total_perks_claimed + 1;
        marketplace.total_revenue_distributed = marketplace.total_revenue_distributed + usdc_value;
        
        // Transfer claimed perk to user
        transfer::public_transfer(claimed_perk, claimer_address);
        
        // Emit claim event
        event::emit(PerkClaimed {
            claimed_perk_id,
            perk_id: object::uid_to_inner(&perk.id),
            claimer_address,
            points_spent: points_cost,
            usdc_value,
            partner_revenue_usdc,
            platform_revenue_usdc,
            timestamp_ms: current_time_ms,
        });
    }
    
    // =================== INTERNAL FUNCTIONS ===================
    
    /// Check if price should be updated
    fun should_update_price(perk: &PerkSimple, current_time_ms: u64): bool {
        current_time_ms - perk.last_price_update_ms > 3600000 // 1 hour
    }
    
    /// Update perk price using oracle
    fun update_perk_price_from_oracle(perk: &mut PerkSimple, oracle: &OracleSimple, current_time_ms: u64) {
        let sui_usd_price = oracle_simple::get_price(oracle, string::utf8(b"SUI/USD"));
        let old_price = perk.current_price_points;
        let new_price = (perk.base_price_usdc * 100000000) / sui_usd_price; // Convert USDC to points
        
        perk.current_price_points = new_price;
        perk.last_price_update_ms = current_time_ms;
        
        let (_, confidence) = oracle_simple::get_price_with_confidence(oracle, string::utf8(b"SUI/USD"));
        
        event::emit(PerkPriceUpdated {
            perk_id: object::uid_to_inner(&perk.id),
            old_price_points: old_price,
            new_price_points: new_price,
            oracle_confidence: confidence,
            timestamp_ms: current_time_ms,
        });
    }
    
    // =================== VIEW FUNCTIONS ===================
    
    /// Get perk info (used by other modules)
    public fun get_perk_info(perk: &PerkSimple): (String, u64, u64, bool) {
        (perk.name, perk.base_price_usdc, perk.current_price_points, perk.is_active)
    }
    
    /// Get marketplace stats (used by other modules)
    public fun get_marketplace_stats(marketplace: &PerkMarketplaceSimple): (u64, u64, u64) {
        (marketplace.total_perks_created, marketplace.total_perks_claimed, marketplace.total_revenue_distributed)
    }
    
    /// Get perk revenue info
    public fun get_perk_revenue_info(perk: &PerkSimple): (u64, u64, u64, u64) {
        (perk.total_claims_count, perk.total_revenue_usdc, perk.partner_revenue_usdc, perk.platform_revenue_usdc)
    }
    
    // =================== ADMIN FUNCTIONS ===================
    
    /// Pause/unpause marketplace
    public entry fun set_marketplace_pause(
        marketplace: &mut PerkMarketplaceSimple,
        config: &ConfigSimple,
        admin_cap: &AdminCapSimple,
        paused: bool,
        _ctx: &mut TxContext
    ) {
        assert!(admin_simple::is_admin(admin_cap, config), EUnauthorized);
        marketplace.is_paused = paused;
    }
    
    /// Deactivate perk
    public entry fun deactivate_perk(
        perk: &mut PerkSimple,
        config: &ConfigSimple,
        admin_cap: &AdminCapSimple,
        _ctx: &mut TxContext
    ) {
        assert!(admin_simple::is_admin(admin_cap, config), EUnauthorized);
        perk.is_active = false;
    }
    
    // =================== TEST-ONLY FUNCTIONS ===================
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
    
    #[test_only]
    public fun create_test_perk(
        name: String,
        base_price_usdc: u64,
        partner_share_bps: u64,
        ctx: &mut TxContext
    ): PerkSimple {
        PerkSimple {
            id: object::new(ctx),
            name,
            description: string::utf8(b"Test perk"),
            category: string::utf8(b"test"),
            creator_partner_cap_id: object::id_from_address(@0x1),
            partner_vault_id: object::id_from_address(@0x2),
            base_price_usdc,
            current_price_points: base_price_usdc * 1000, // Simple conversion
            partner_share_bps,
            is_active: true,
            max_total_claims: option::none(),
            total_claims_count: 0,
            total_revenue_usdc: 0,
            partner_revenue_usdc: 0,
            platform_revenue_usdc: 0,
            created_timestamp_ms: 0,
            last_price_update_ms: 0,
        }
    }
    
    #[test_only]
    public fun destroy_test_perk(perk: PerkSimple) {
        let PerkSimple { 
            id, 
            name: _, 
            description: _, 
            category: _, 
            creator_partner_cap_id: _, 
            partner_vault_id: _, 
            base_price_usdc: _, 
            current_price_points: _, 
            partner_share_bps: _, 
            is_active: _, 
            max_total_claims: _, 
            total_claims_count: _, 
            total_revenue_usdc: _, 
            partner_revenue_usdc: _, 
            platform_revenue_usdc: _, 
            created_timestamp_ms: _, 
            last_price_update_ms: _ 
        } = perk;
        object::delete(id);
    }
}
