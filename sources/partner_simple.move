#[allow(duplicate_alias, unused_use)]
/// Simplified Partner Module - USDC Vault Management for B2B Platform
/// 
/// Core Features:
/// 1. USDC VAULT CREATION - Partners deposit USDC to get point quotas
/// 2. QUOTA ALLOCATION - Based on USDC deposited (1 USD = 1000 points quota)
/// 3. POINT MINTING - Partners mint points against their quota with USDC backing
/// 4. USDC WITHDRAWAL - Partners can withdraw unused USDC with safety checks
/// 5. REMOVED COMPLEXITY - No DeFi integration, yield farming, or complex health calculations
module alpha_points::partner_simple {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use std::string::{Self, String};
    use std::option::Option;
    
    // Import simplified modules
    use alpha_points::admin_simple::{Self, ConfigSimple, AdminCapSimple};
    use alpha_points::ledger_simple::{Self, LedgerSimple};
    
    // USDC Type (placeholder - actual implementation would import from USDC package)
    public struct USDC has drop {}
    
    // =================== CONSTANTS ===================
    
    // Vault management
    const MIN_VAULT_VALUE_USDC: u64 = 100_000_000;       // $100 minimum (6 decimals)
    const VAULT_SAFETY_BUFFER_BPS: u64 = 1100;           // 110% collateralization required
    const DAILY_QUOTA_BPS: u64 = 500;                    // 5% of lifetime quota daily
    const DAILY_RESET_INTERVAL_MS: u64 = 86400000;       // 24 hours
    
    // =================== ERROR CONSTANTS ===================
    
    const EUnauthorized: u64 = 1;
    const EPartnerPaused: u64 = 2;
    const EInsufficientQuota: u64 = 3;
    const EInsufficientCollateral: u64 = 4;
    const EInvalidCollateralAmount: u64 = 5;
    const EExcessiveWithdrawal: u64 = 6;
    const EInvalidQuotaAmount: u64 = 7;
    const EInvalidPartnerName: u64 = 8;
    const ECollateralLocked: u64 = 9;
    const EQuotaExhausted: u64 = 10;
    const EInvalidWithdrawalAmount: u64 = 11;
    const EPartnerAlreadyExists: u64 = 12;
    const EInvalidVaultState: u64 = 13;
    
    // =================== STRUCTS ===================
    
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
        partner_name: String,
        vault_id: ID,                      // Associated vault
        
        // Simple quota tracking
        daily_quota_points: u64,           // Daily minting limit
        daily_quota_used: u64,             // Used today
        last_quota_reset_day: u64,         // Last reset (days since epoch)
        
        // Status
        is_active: bool,
        is_paused: bool,
    }
    
    /// Simple partner registry
    public struct PartnerRegistrySimple has key {
        id: UID,
        
        // Partner organization
        partner_caps: Table<address, ID>,   // partner_address -> PartnerCap ID
        partner_vaults: Table<address, ID>, // partner_address -> PartnerVault ID
        active_partners: vector<address>,
        
        // Global stats
        total_partners: u64,
        total_usdc_deposited: u64,
        total_quota_allocated: u64,
        total_quota_utilized: u64,
        
        // Controls
        is_paused: bool,
        admin_cap_id: ID,
    }
    
    // =================== EVENTS ===================
    
    public struct PartnerOnboarded has copy, drop {
        partner_address: address,
        partner_name: String,
        vault_id: ID,
        usdc_deposited: u64,
        lifetime_quota_allocated: u64,
        daily_quota_allocated: u64,
        timestamp_ms: u64,
    }
    
    public struct QuotaUtilized has copy, drop {
        partner_address: address,
        user_address: address,
        points_minted: u64,
        usdc_reserved: u64,
        daily_quota_remaining: u64,
        lifetime_quota_remaining: u64,
        timestamp_ms: u64,
    }
    
    public struct UsdcWithdrawn has copy, drop {
        partner_address: address,
        vault_id: ID,
        usdc_withdrawn: u64,
        remaining_usdc: u64,
        remaining_quota: u64,
        timestamp_ms: u64,
    }
    
    public struct DailyQuotaReset has copy, drop {
        partner_address: address,
        reset_day: u64,
        daily_quota: u64,
        timestamp_ms: u64,
    }
    
    // =================== INITIALIZATION ===================
    
    /// Initialize partner system
    fun init(_ctx: &mut TxContext) {
        // Registry should be created via create_partner_registry_simple
    }
    
    /// Create partner registry
    public entry fun create_partner_registry_simple(
        config: &ConfigSimple,
        admin_cap: &AdminCapSimple,
        ctx: &mut TxContext
    ) {
        assert!(admin_simple::is_admin(admin_cap, config), EUnauthorized);
        
        let registry = PartnerRegistrySimple {
            id: object::new(ctx),
            partner_caps: table::new(ctx),
            partner_vaults: table::new(ctx),
            active_partners: vector::empty(),
            total_partners: 0,
            total_usdc_deposited: 0,
            total_quota_allocated: 0,
            total_quota_utilized: 0,
            is_paused: false,
            admin_cap_id: admin_simple::get_admin_cap_id(admin_cap),
        };
        
        transfer::share_object(registry);
    }
    
    // =================== CORE FUNCTIONS ===================
    
    /// Partner onboarding (core B2B function)
    public entry fun create_partner_and_vault(
        registry: &mut PartnerRegistrySimple,
        config: &ConfigSimple,
        partner_name: String,
        vault_name: String,
        usdc_collateral: Coin<USDC>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate inputs
        admin_simple::assert_not_paused(config);
        assert!(!string::is_empty(&partner_name), EInvalidPartnerName);
        assert!(!string::is_empty(&vault_name), EInvalidPartnerName);
        assert!(!registry.is_paused, EPartnerPaused);
        
        let partner_address = tx_context::sender(ctx);
        let current_time_ms = clock::timestamp_ms(clock);
        let usdc_amount = coin::value(&usdc_collateral);
        
        // Validate minimum vault size
        assert!(usdc_amount >= MIN_VAULT_VALUE_USDC, EInvalidCollateralAmount);
        
        // Check partner doesn't already exist
        assert!(!table::contains(&registry.partner_caps, partner_address), EPartnerAlreadyExists);
        
        // Calculate quota allocation using admin_simple parameters
        let points_per_usd = admin_simple::get_points_per_usd(config);
        let usdc_value_usd = usdc_amount / 1_000_000; // Convert USDC (6 decimals) to USD
        let lifetime_quota = usdc_value_usd * points_per_usd;
        let daily_quota = (lifetime_quota * DAILY_QUOTA_BPS) / 10000;
        
        // Create vault
        let vault = PartnerVaultSimple {
            id: object::new(ctx),
            partner_address,
            vault_name,
            created_timestamp_ms: current_time_ms,
            usdc_balance: coin::into_balance(usdc_collateral),
            reserved_for_backing: 0,
            available_for_withdrawal: usdc_amount,
            lifetime_quota_points: lifetime_quota,
            outstanding_points_minted: 0,
            is_active: true,
            is_locked: false,
        };
        
        let vault_id = object::uid_to_inner(&vault.id);
        
        // Create partner capability
        let partner_cap = PartnerCapSimple {
            id: object::new(ctx),
            partner_address,
            partner_name,
            vault_id,
            daily_quota_points: daily_quota,
            daily_quota_used: 0,
            last_quota_reset_day: current_time_ms / DAILY_RESET_INTERVAL_MS,
            is_active: true,
            is_paused: false,
        };
        
        let partner_cap_id = object::uid_to_inner(&partner_cap.id);
        
        // Update registry
        table::add(&mut registry.partner_caps, partner_address, partner_cap_id);
        table::add(&mut registry.partner_vaults, partner_address, vault_id);
        vector::push_back(&mut registry.active_partners, partner_address);
        
        registry.total_partners = registry.total_partners + 1;
        registry.total_usdc_deposited = registry.total_usdc_deposited + usdc_amount;
        registry.total_quota_allocated = registry.total_quota_allocated + lifetime_quota;
        
        // Transfer objects to partner
        transfer::public_transfer(partner_cap, partner_address);
        transfer::public_transfer(vault, partner_address);
        
        // Emit onboarding event
        event::emit(PartnerOnboarded {
            partner_address,
            partner_name,
            vault_id,
            usdc_deposited: usdc_amount,
            lifetime_quota_allocated: lifetime_quota,
            daily_quota_allocated: daily_quota,
            timestamp_ms: current_time_ms,
        });
    }
    
    /// Quota utilization (core integration function)
    public entry fun mint_points_against_quota(
        registry: &mut PartnerRegistrySimple,
        config: &ConfigSimple,
        partner_cap: &mut PartnerCapSimple,
        vault: &mut PartnerVaultSimple,
        ledger: &mut LedgerSimple,
        user_address: address,
        points_amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate system state and authorization
        admin_simple::assert_mint_not_paused(config);
        assert!(tx_context::sender(ctx) == partner_cap.partner_address, EUnauthorized);
        assert!(!partner_cap.is_paused, EPartnerPaused);
        assert!(!vault.is_locked, ECollateralLocked);
        assert!(object::uid_to_inner(&vault.id) == partner_cap.vault_id, EInvalidVaultState);
        assert!(points_amount > 0, EInvalidQuotaAmount);
        
        let current_time_ms = clock::timestamp_ms(clock);
        
        // Reset daily quota if needed
        reset_daily_quota_if_needed(partner_cap, current_time_ms);
        
        // Check quota availability
        assert!(partner_cap.daily_quota_used + points_amount <= partner_cap.daily_quota_points, EQuotaExhausted);
        assert!(vault.outstanding_points_minted + points_amount <= vault.lifetime_quota_points, EInsufficientQuota);
        
        // Calculate USDC backing requirement
        let points_per_usd = admin_simple::get_points_per_usd(config);
        let usdc_backing_required = if (points_per_usd > 0) {
            ((points_amount + points_per_usd - 1) / points_per_usd) * 1_000_000 // Convert to USDC (6 decimals)
        } else {
            0
        };
        
        // Ensure sufficient USDC backing
        let vault_balance = balance::value(&vault.usdc_balance);
        let total_backing_after = vault.reserved_for_backing + usdc_backing_required;
        assert!(vault_balance >= total_backing_after, EInsufficientCollateral);
        
        // Update partner and vault state
        partner_cap.daily_quota_used = partner_cap.daily_quota_used + points_amount;
        
        vault.outstanding_points_minted = vault.outstanding_points_minted + points_amount;
        vault.reserved_for_backing = vault.reserved_for_backing + usdc_backing_required;
        vault.available_for_withdrawal = vault_balance - vault.reserved_for_backing;
        
        // Mint points using ledger_simple
        ledger_simple::mint_points(
            ledger,
            config,
            user_address,
            points_amount,
            ledger_simple::partner_reward_type(),
            clock,
            ctx
        );
        
        // Update registry
        registry.total_quota_utilized = registry.total_quota_utilized + points_amount;
        
        // Emit quota utilization event
        event::emit(QuotaUtilized {
            partner_address: partner_cap.partner_address,
            user_address,
            points_minted: points_amount,
            usdc_reserved: usdc_backing_required,
            daily_quota_remaining: partner_cap.daily_quota_points - partner_cap.daily_quota_used,
            lifetime_quota_remaining: vault.lifetime_quota_points - vault.outstanding_points_minted,
            timestamp_ms: current_time_ms,
        });
    }
    
    /// USDC management (core financial function)
    public fun withdraw_usdc_from_vault(
        config: &ConfigSimple,
        partner_cap: &PartnerCapSimple,
        vault: &mut PartnerVaultSimple,
        withdrawal_amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<USDC> {
        // Validate caller and system state
        admin_simple::assert_not_paused(config);
        assert!(tx_context::sender(ctx) == partner_cap.partner_address, EUnauthorized);
        assert!(!partner_cap.is_paused, EPartnerPaused);
        assert!(!vault.is_locked, ECollateralLocked);
        assert!(object::uid_to_inner(&vault.id) == partner_cap.vault_id, EInvalidVaultState);
        assert!(withdrawal_amount > 0, EInvalidWithdrawalAmount);
        
        let current_time_ms = clock::timestamp_ms(clock);
        
        // CORE BUSINESS LOGIC: Calculate how much USDC is actually available
        let points_per_usd = admin_simple::get_points_per_usd(config);
        let usdc_required_for_backing = if (points_per_usd > 0) {
            ((vault.outstanding_points_minted + points_per_usd - 1) / points_per_usd) * 1_000_000 // Convert to USDC (6 decimals)
        } else {
            0
        };
        
        // Add safety buffer - require 110% backing
        let usdc_required_with_buffer = (usdc_required_for_backing * VAULT_SAFETY_BUFFER_BPS) / 10000;
        
        // Calculate truly available USDC
        let vault_total_usdc = balance::value(&vault.usdc_balance);
        let truly_available_usdc = if (vault_total_usdc > usdc_required_with_buffer) {
            vault_total_usdc - usdc_required_with_buffer
        } else {
            0
        };
        
        // Validate withdrawal amount
        assert!(withdrawal_amount <= truly_available_usdc, EExcessiveWithdrawal);
        
        // Perform withdrawal
        let withdrawn_balance = balance::split(&mut vault.usdc_balance, withdrawal_amount);
        let withdrawn_coin = coin::from_balance(withdrawn_balance, ctx);
        
        // Update vault state
        let remaining_usdc = balance::value(&vault.usdc_balance);
        vault.available_for_withdrawal = if (remaining_usdc > vault.reserved_for_backing) {
            remaining_usdc - vault.reserved_for_backing
        } else {
            0
        };
        
        // Emit withdrawal event
        event::emit(UsdcWithdrawn {
            partner_address: partner_cap.partner_address,
            vault_id: object::uid_to_inner(&vault.id),
            usdc_withdrawn: withdrawal_amount,
            remaining_usdc,
            remaining_quota: vault.lifetime_quota_points - vault.outstanding_points_minted,
            timestamp_ms: current_time_ms,
        });
        
        withdrawn_coin
    }
    
    // =================== INTERNAL FUNCTIONS ===================
    
    /// Reset daily quota if needed
    fun reset_daily_quota_if_needed(partner_cap: &mut PartnerCapSimple, current_time_ms: u64) {
        let current_day = current_time_ms / DAILY_RESET_INTERVAL_MS;
        
        if (current_day > partner_cap.last_quota_reset_day) {
            partner_cap.daily_quota_used = 0;
            partner_cap.last_quota_reset_day = current_day;
            
            event::emit(DailyQuotaReset {
                partner_address: partner_cap.partner_address,
                reset_day: current_day,
                daily_quota: partner_cap.daily_quota_points,
                timestamp_ms: current_time_ms,
            });
        };
    }
    
    // =================== VIEW FUNCTIONS ===================
    
    /// Get vault info (used by other modules)
    public fun get_vault_info(vault: &PartnerVaultSimple): (u64, u64, u64) {
        (
            balance::value(&vault.usdc_balance),  // total_usdc
            vault.reserved_for_backing,           // reserved
            vault.available_for_withdrawal        // available
        )
    }
    
    /// Get quota info (used by other modules)
    public fun get_quota_info(cap: &PartnerCapSimple): (u64, u64) {
        (cap.daily_quota_points, cap.daily_quota_used)
    }
    
    /// Check if partner can mint points
    public fun can_mint_points(vault: &PartnerVaultSimple, amount: u64): bool {
        vault.outstanding_points_minted + amount <= vault.lifetime_quota_points
    }
    
    /// Get partner address from capability
    public fun get_partner_address(cap: &PartnerCapSimple): address {
        cap.partner_address
    }
    
    /// Get vault partner address
    public fun get_vault_partner_address(vault: &PartnerVaultSimple): address {
        vault.partner_address
    }
    
    /// Check if partner is paused
    public fun is_paused(cap: &PartnerCapSimple): bool {
        cap.is_paused
    }
    
    /// Get partner capability UID to inner
    public fun get_partner_cap_uid_to_inner(cap: &PartnerCapSimple): ID {
        object::uid_to_inner(&cap.id)
    }
    
    /// Get partner vault UID to inner  
    public fun get_partner_vault_uid_to_inner(vault: &PartnerVaultSimple): ID {
        object::uid_to_inner(&vault.id)
    }
    
    // =================== ADMIN FUNCTIONS ===================
    
    /// Pause/unpause partner
    public entry fun set_partner_pause(
        config: &ConfigSimple,
        admin_cap: &AdminCapSimple,
        partner_cap: &mut PartnerCapSimple,
        paused: bool,
        _ctx: &mut TxContext
    ) {
        assert!(admin_simple::is_admin(admin_cap, config), EUnauthorized);
        partner_cap.is_paused = paused;
    }
    
    /// Lock/unlock vault
    public entry fun set_vault_lock(
        config: &ConfigSimple,
        admin_cap: &AdminCapSimple,
        vault: &mut PartnerVaultSimple,
        locked: bool,
        _ctx: &mut TxContext
    ) {
        assert!(admin_simple::is_admin(admin_cap, config), EUnauthorized);
        vault.is_locked = locked;
    }
    
    // =================== TEST-ONLY FUNCTIONS ===================
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
    
    #[test_only]
    public fun create_test_partner_and_vault(
        partner_name: String,
        usdc_amount: u64,
        ctx: &mut TxContext
    ): (PartnerCapSimple, PartnerVaultSimple) {
        let partner_address = tx_context::sender(ctx);
        let vault_id = object::id_from_address(@0x1);
        
        let vault = PartnerVaultSimple {
            id: object::new(ctx),
            partner_address,
            vault_name: string::utf8(b"Test Vault"),
            created_timestamp_ms: 0,
            usdc_balance: balance::zero<USDC>(),
            reserved_for_backing: 0,
            available_for_withdrawal: usdc_amount,
            lifetime_quota_points: usdc_amount * 1000, // 1000 points per USDC
            outstanding_points_minted: 0,
            is_active: true,
            is_locked: false,
        };
        
        let partner_cap = PartnerCapSimple {
            id: object::new(ctx),
            partner_address,
            partner_name,
            vault_id,
            daily_quota_points: usdc_amount * 50, // 5% daily quota
            daily_quota_used: 0,
            last_quota_reset_day: 0,
            is_active: true,
            is_paused: false,
        };
        
        (partner_cap, vault)
    }
    
    #[test_only]
    public fun destroy_test_partner_cap(cap: PartnerCapSimple) {
        let PartnerCapSimple { 
            id, 
            partner_address: _, 
            partner_name: _, 
            vault_id: _, 
            daily_quota_points: _, 
            daily_quota_used: _, 
            last_quota_reset_day: _, 
            is_active: _, 
            is_paused: _ 
        } = cap;
        object::delete(id);
    }
    
    #[test_only]
    public fun destroy_test_vault(vault: PartnerVaultSimple) {
        let PartnerVaultSimple { 
            id, 
            partner_address: _, 
            vault_name: _, 
            created_timestamp_ms: _, 
            usdc_balance, 
            reserved_for_backing: _, 
            available_for_withdrawal: _, 
            lifetime_quota_points: _, 
            outstanding_points_minted: _, 
            is_active: _, 
            is_locked: _ 
        } = vault;
        
        balance::destroy_zero(usdc_balance);
        object::delete(id);
    }
}
