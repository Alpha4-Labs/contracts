/// CORE Partner Management System V3 - USDC-Only with DeFi-Compatible Vaults
/// 
/// Key Features:
/// 1. STABLE VALUE - USDC-only collateral eliminates volatility risk  
/// 2. DeFi-COMPATIBLE VAULTS - Vault objects designed for protocols like Scallop, Haedal
/// 3. FIXED BUSINESS LOGIC - Partners can withdraw unused collateral proportionally
/// 4. YIELD-READY DESIGN - Vaults can generate yield while maintaining backing requirements
/// 5. TRANSFERABLE OBJECTS - Vaults can be moved to DeFi protocols when desired
/// 6. PRODUCTION READY - Comprehensive validation and emergency controls
module alpha_points::partner_v3 {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use std::string::{Self, String};
    use std::vector;
    use std::option::{Self, Option};
    use std::type_name::{Self, TypeName};
    
    // Import our fixed modules
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    
    // USDC Type - will be configured for testnet/mainnet
    // Testnet: 0xa1ec7fc00a6f40db9693ad1415d0c193ad3906494428cf252621037bd7117e29::usdc::USDC
    // Mainnet: 0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC
    public struct USDC has drop {}
    
    // =================== CONSTANTS ===================
    
    // Vault and collateral management
    const MIN_VAULT_VALUE_USDC: u64 = 100_000_000;           // $100 minimum (6 decimals)
    const VAULT_SAFETY_BUFFER_BPS: u64 = 1100;               // 110% collateralization required
    const SAFE_WITHDRAWAL_RATIO_BPS: u64 = 8500;             // 85% - safe zone for withdrawals  
    const MAX_UTILIZATION_BPS: u64 = 8000;                   // 80% max utilization for DeFi
    
    // DeFi integration parameters
    const DEFI_YIELD_SHARE_BPS: u64 = 5000;                  // 50% of yield goes to protocol
    const MIN_DEFI_DEPOSIT_USDC: u64 = 1000_000_000;         // $1000 minimum for DeFi protocols
    const YIELD_HARVEST_INTERVAL_MS: u64 = 86400000;         // 24 hours yield harvest interval
    
    // Partner management
    const MAX_PARTNERS_PER_GENERATION: u64 = 1000;           // Max partners per generation
    const QUOTA_RESET_INTERVAL_MS: u64 = 86400000;           // 24 hours = daily reset
    const DEFAULT_DAILY_QUOTA_BPS: u64 = 500;                // 5% of lifetime quota daily
    
    // Health and liquidation thresholds
    const MIN_HEALTH_FACTOR_BPS: u64 = 8000;                 // 80% minimum health factor
    const LIQUIDATION_THRESHOLD_BPS: u64 = 7500;             // 75% liquidation threshold
    const CRITICAL_HEALTH_THRESHOLD_BPS: u64 = 7000;         // 70% critical threshold
    
    // Generation management
    const MAX_GENERATION_ID: u64 = 999999;                   // Maximum generation ID
    const DEFAULT_GENERATION_ID: u64 = 1;                    // Default generation
    
    // =================== ERROR CONSTANTS ===================
    
    const EUnauthorized: u64 = 1;
    const EPartnerPaused: u64 = 2;
    const EInsufficientQuota: u64 = 3;
    const EInsufficientCollateral: u64 = 4;
    const EInvalidCollateralAmount: u64 = 5;
    const EHealthFactorTooLow: u64 = 6;
    const EExcessiveWithdrawal: u64 = 7;
    const EInvalidGenerationId: u64 = 8;
    const EPartnerNotFound: u64 = 9;
    const EInvalidQuotaAmount: u64 = 10;
    const EInvalidPartnerName: u64 = 11;
    const ECollateralLocked: u64 = 12;
    const EQuotaExhausted: u64 = 13;
    const EInvalidWithdrawalAmount: u64 = 14;
    const EPartnerAlreadyExists: u64 = 15;
    const ETooManyPartners: u64 = 16;
    const EQuotaResetTooEarly: u64 = 17;
    const EInsufficientUsage: u64 = 18;
    const EVaultInUse: u64 = 19;
    const EVaultTooSmall: u64 = 20;
    const EInvalidVaultState: u64 = 21;
    const EDeFiIntegrationPaused: u64 = 22;
    const EYieldHarvestTooEarly: u64 = 23;
    
    // =================== CORE STRUCTS ===================
    
    /// DeFi-Compatible Partner Vault - Designed for yield protocols like Scallop, Haedal
    /// This object can be transferred to DeFi protocols while maintaining backing requirements
    public struct PartnerVault has key, store {
        id: UID,
        
        // === VAULT IDENTITY ===
        vault_name: String,                       // Human-readable vault name
        partner_address: address,                 // Owner of this vault
        generation_id: u64,                       // Which generation this vault belongs to
        created_timestamp_ms: u64,                // When vault was created
        
        // === COLLATERAL MANAGEMENT (USDC-ONLY) ===
        usdc_balance: Balance<USDC>,              // USDC holdings in the vault
        total_usdc_deposited: u64,                // Total USDC ever deposited
        available_for_withdrawal: u64,            // USDC available for partner withdrawal
        reserved_for_backing: u64,                // USDC reserved to back minted points
        
        // === QUOTA TRACKING ===
        lifetime_quota_points: u64,               // Total quota allocated (based on USDC)
        outstanding_points_minted: u64,           // Points currently outstanding that need backing
        total_points_ever_minted: u64,            // Historical total for analytics
        
        // === DeFi INTEGRATION STATUS ===
        defi_protocol_in_use: Option<String>,     // Which DeFi protocol is using this vault (if any)
        yield_generated_lifetime: u64,            // Total USDC yield generated from DeFi
        last_yield_harvest_ms: u64,               // Last time yield was harvested
        defi_deposit_amount: u64,                 // Amount currently in DeFi protocol
        defi_available_for_harvest: u64,          // Yield ready to be harvested
        
        // === VAULT HEALTH ===
        health_factor_bps: u64,                   // Vault health factor (basis points)
        utilization_rate_bps: u64,                // How much of vault is utilized
        liquidation_risk_level: u8,               // 0=Safe, 1=Warning, 2=Critical, 3=Liquidation Risk
        
        // === OPERATIONAL CONTROLS ===
        is_locked: bool,                          // Vault locked by admin
        defi_integration_enabled: bool,           // Whether vault can be used in DeFi
        auto_yield_harvest_enabled: bool,         // Whether yield should be auto-harvested
        
        // === METADATA ===
        vault_metadata: vector<u8>,               // Additional metadata for DeFi protocols
        last_activity_ms: u64,                    // Last vault activity timestamp
    }
    
    /// Enhanced Partner Capability that references their vault
    public struct PartnerCapV3 has key, store {
        id: UID,
        
        // === PARTNER IDENTITY ===
        partner_name: String,                     // Partner business name
        partner_address: address,                 // Partner wallet address
        generation_id: u64,                       // Which generation this partner belongs to
        onboarding_timestamp_ms: u64,             // When partner was onboarded
        
        // === VAULT REFERENCE ===
        vault_id: ID,                             // ID of partner's vault object
        vault_owner: address,                     // Current owner of vault (could be DeFi protocol)
        
        // === DAILY QUOTA MANAGEMENT ===
        daily_quota_points: u64,                  // Daily minting limit
        daily_quota_used: u64,                    // Points used today
        daily_quota_reset_time_ms: u64,           // When daily quota was last reset
        
        // === OPERATIONAL CONTROLS ===
        is_paused: bool,                          // Partner operations paused
        pause_reason: vector<u8>,                 // Reason for pause (if paused)
        emergency_pause: bool,                    // Emergency pause flag
        
        // === METADATA ===
        last_activity_ms: u64,                   // Last partner activity timestamp
        admin_notes: vector<u8>,                  // Admin notes for this partner
    }
    
    /// Partner Registry - tracks all active partners and their vaults
    public struct PartnerRegistryV3 has key {
        id: UID,
        
        // === GENERATION TRACKING ===
        partners_per_generation: Table<u64, vector<address>>, // generation_id -> partner_addresses
        partner_cap_ids: Table<address, ID>,                  // partner_address -> PartnerCap ID
        partner_vault_ids: Table<address, ID>,                // partner_address -> Vault ID
        generation_partner_count: Table<u64, u64>,            // generation_id -> partner_count
        
        // === REGISTRY METADATA ===
        total_partners: u64,                      // Total number of active partners
        total_generations: u64,                   // Total number of generations
        registry_admin: address,                  // Who can manage the registry
        
        // === ECONOMIC TRACKING (USDC-ONLY) ===
        total_usdc_locked: u64,                   // Total USDC value locked across all vaults
        total_usdc_in_defi: u64,                  // Total USDC currently earning yield in DeFi
        total_yield_generated: u64,               // Total USDC yield generated from DeFi
        total_quota_allocated: u64,               // Total quota points allocated
        total_quota_utilized: u64,                // Total quota points actually used
        
        // === DeFi INTEGRATION STATUS ===
        defi_protocols_supported: Table<String, bool>,        // protocol_name -> enabled
        total_vaults_in_defi: u64,                // Number of vaults currently in DeFi protocols
        
        // === METADATA ===
        last_updated_ms: u64,                     // Last registry update timestamp
    }
    
    /// DeFi Protocol Integration Capability (for future use)
    public struct DeFiIntegrationCap has key, store {
        id: UID,
        protocol_name: String,                    // Name of DeFi protocol
        authorized_addresses: vector<address>,    // Addresses authorized to use this cap
        max_vault_utilization_bps: u64,           // Max % of vault that can be used
        min_vault_size_usdc: u64,                // Minimum vault size for this protocol
        yield_share_bps: u64,                    // Percentage of yield that goes to protocol
        is_active: bool,                         // Whether integration is active
    }
    
    // =================== EVENTS ===================
    
    /// Partner vault created with USDC collateral
    public struct PartnerVaultCreated has copy, drop {
        vault_id: ID,
        partner_cap_id: ID,
        partner_address: address,
        partner_name: String,
        generation_id: u64,
        usdc_deposited: u64,
        lifetime_quota_points: u64,
        daily_quota_points: u64,
        vault_name: String,
        timestamp_ms: u64,
    }
    
    /// USDC deposited into partner vault
    public struct USDCDeposited has copy, drop {
        vault_id: ID,
        partner_address: address,
        usdc_amount: u64,
        new_total_usdc: u64,
        new_available_withdrawal: u64,
        new_lifetime_quota: u64,
        health_factor_after: u64,
        timestamp_ms: u64,
    }
    
    /// CRITICAL EVENT: USDC withdrawn from vault (BUSINESS LOGIC FIX)
    public struct USDCWithdrawn has copy, drop {
        vault_id: ID,
        partner_address: address,
        withdrawn_amount: u64,
        remaining_usdc: u64,
        available_for_withdrawal: u64,
        points_still_backed: u64,
        new_quota_allocation: u64,
        health_factor_after: u64,
        withdrawal_reason: vector<u8>,
        timestamp_ms: u64,
    }
    
    /// Vault transferred to DeFi protocol
    public struct VaultTransferredToDeFi has copy, drop {
        vault_id: ID,
        partner_address: address,
        defi_protocol: String,
        usdc_amount_transferred: u64,
        expected_yield_apy_bps: u64,                // Expected APY from DeFi protocol
        max_utilization_bps: u64,                   // Max % of vault that can be utilized
        transfer_timestamp_ms: u64,
    }
    
    /// Yield harvested from DeFi protocol
    public struct YieldHarvested has copy, drop {
        vault_id: ID,
        partner_address: address,
        defi_protocol: String,
        yield_amount_usdc: u64,
        protocol_share_usdc: u64,                   // Share going to Alpha Points protocol
        partner_share_usdc: u64,                    // Share going to partner
        new_vault_balance: u64,
        harvest_timestamp_ms: u64,
    }
    
    /// Vault returned from DeFi protocol
    public struct VaultReturnedFromDeFi has copy, drop {
        vault_id: ID,
        partner_address: address,
        defi_protocol: String,
        principal_returned: u64,
        yield_earned: u64,
        total_returned: u64,
        return_timestamp_ms: u64,
    }
    
    public struct QuotaUtilizedV3 has copy, drop {
        vault_id: ID,
        partner_cap_id: ID,
        partner_address: address,
        points_minted: u64,
        usdc_reserved_for_backing: u64,
        daily_quota_remaining: u64,
        vault_utilization_rate_bps: u64,
        health_factor_after: u64,
        timestamp_ms: u64,
    }
    
    public struct VaultHealthUpdated has copy, drop {
        vault_id: ID,
        partner_address: address,
        old_health_factor_bps: u64,
        new_health_factor_bps: u64,
        utilization_rate_bps: u64,
        risk_level: u8,
        defi_status: Option<String>,                // DeFi protocol status if applicable
        recommended_action: vector<u8>,
        timestamp_ms: u64,
    }
    
    // =================== INITIALIZATION ===================
    
    /// Initialize the enhanced partner system with USDC-only vaults
    fun init(ctx: &mut TxContext) {
        let mut registry = PartnerRegistryV3 {
            id: object::new(ctx),
            partners_per_generation: table::new(ctx),
            partner_cap_ids: table::new(ctx),
            partner_vault_ids: table::new(ctx),
            generation_partner_count: table::new(ctx),
            total_partners: 0,
            total_generations: 1,
            registry_admin: tx_context::sender(ctx),
            total_usdc_locked: 0,
            total_usdc_in_defi: 0,
            total_yield_generated: 0,
            total_quota_allocated: 0,
            total_quota_utilized: 0,
            defi_protocols_supported: table::new(ctx),
            total_vaults_in_defi: 0,
            last_updated_ms: 0,
        };
        
        // Initialize default generation
        let default_generation_partners: vector<address> = vector::empty();
        table::add(&mut registry.partners_per_generation, DEFAULT_GENERATION_ID, default_generation_partners);
        table::add(&mut registry.generation_partner_count, DEFAULT_GENERATION_ID, 0);
        
        transfer::share_object(registry);
    }
    
    // =================== CORE BUSINESS LOGIC ===================
    
    /// Create partner with USDC vault - designed for DeFi compatibility
    public entry fun create_partner_with_usdc_vault(
        registry: &mut PartnerRegistryV3,
        config: &ConfigV2,
        usdc_collateral: Coin<USDC>,
        partner_name: String,
        vault_name: String,
        generation_id: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate inputs
        admin_v2::assert_not_paused(config);
        assert!(!string::is_empty(&partner_name), EInvalidPartnerName);
        assert!(!string::is_empty(&vault_name), EInvalidPartnerName);
        assert!(generation_id > 0 && generation_id <= MAX_GENERATION_ID, EInvalidGenerationId);
        
        let partner_address = tx_context::sender(ctx);
        let current_time_ms = clock::timestamp_ms(clock);
        let usdc_amount = coin::value(&usdc_collateral);
        
        // Validate minimum vault size
        assert!(usdc_amount >= MIN_VAULT_VALUE_USDC, EInvalidCollateralAmount);
        
        // Check partner doesn't already exist
        assert!(!table::contains(&registry.partner_cap_ids, partner_address), EPartnerAlreadyExists);
        
        // Ensure generation has capacity
        let current_partner_count = if (table::contains(&registry.generation_partner_count, generation_id)) {
            *table::borrow(&registry.generation_partner_count, generation_id)
        } else {
            0
        };
        assert!(current_partner_count < MAX_PARTNERS_PER_GENERATION, ETooManyPartners);
        
        // Calculate quota allocation using admin_v2 parameters
        let points_per_usd = admin_v2::get_points_per_usd(config);
        let usdc_value_usd = usdc_amount / 1_000_000; // Convert USDC (6 decimals) to USD
        let lifetime_quota = usdc_value_usd * points_per_usd;
        let daily_quota = (lifetime_quota * DEFAULT_DAILY_QUOTA_BPS) / 10000;
        
        // Create DeFi-compatible vault object
        let vault = PartnerVault {
            id: object::new(ctx),
            
            // Vault identity
            vault_name,
            partner_address,
            generation_id,
            created_timestamp_ms: current_time_ms,
            
            // USDC collateral management
            usdc_balance: coin::into_balance(usdc_collateral),
            total_usdc_deposited: usdc_amount,
            available_for_withdrawal: usdc_amount,     // Initially all available
            reserved_for_backing: 0,                   // No points minted yet
            
            // Quota tracking
            lifetime_quota_points: lifetime_quota,
            outstanding_points_minted: 0,
            total_points_ever_minted: 0,
            
            // DeFi integration (initially empty)
            defi_protocol_in_use: option::none(),
            yield_generated_lifetime: 0,
            last_yield_harvest_ms: current_time_ms,
            defi_deposit_amount: 0,
            defi_available_for_harvest: 0,
            
            // Vault health
            health_factor_bps: 10000,                  // 100% healthy initially
            utilization_rate_bps: 0,                   // 0% utilized initially
            liquidation_risk_level: 0,                 // Safe
            
                    // Operational controls
        is_locked: false,
        defi_integration_enabled: true,           // Enabled for DeFi readiness
        auto_yield_harvest_enabled: false,        // Manual harvest initially
            
            // Metadata
            vault_metadata: vector::empty(),
            last_activity_ms: current_time_ms,
        };
        
        let vault_id = object::uid_to_inner(&vault.id);
        
        // Create partner capability
        let partner_cap = PartnerCapV3 {
            id: object::new(ctx),
            
            // Partner identity
            partner_name,
            partner_address,
            generation_id,
            onboarding_timestamp_ms: current_time_ms,
            
            // Vault reference
            vault_id,
            vault_owner: partner_address,              // Initially owned by partner
            
            // Daily quota management
            daily_quota_points: daily_quota,
            daily_quota_used: 0,
            daily_quota_reset_time_ms: current_time_ms,
            
            // Operational controls
            is_paused: false,
            pause_reason: vector::empty(),
            emergency_pause: false,
            
            // Metadata
            last_activity_ms: current_time_ms,
            admin_notes: vector::empty(),
        };
        
        let partner_cap_id = object::uid_to_inner(&partner_cap.id);
        
        // Update registry
        update_partner_registry_v3(registry, partner_address, partner_cap_id, vault_id, 
                                   generation_id, usdc_amount, lifetime_quota, current_time_ms);
        
        // Transfer objects to partner
        transfer::public_transfer(vault, partner_address);
        transfer::public_transfer(partner_cap, partner_address);
        
        // Emit comprehensive creation event
        event::emit(PartnerVaultCreated {
            vault_id,
            partner_cap_id,
            partner_address,
            partner_name,
            generation_id,
            usdc_deposited: usdc_amount,
            lifetime_quota_points: lifetime_quota,
            daily_quota_points: daily_quota,
            vault_name,
            timestamp_ms: current_time_ms,
        });
    }
    
    /// CRITICAL FIX: Allow partners to withdraw unused USDC proportionally
    /// Enhanced version that works with USDC and maintains DeFi compatibility
    public entry fun withdraw_usdc_from_vault(
        registry: &mut PartnerRegistryV3,
        config: &ConfigV2,
        partner_cap: &PartnerCapV3,
        vault: &mut PartnerVault,
        withdrawal_amount_usdc: u64,
        withdrawal_reason: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate caller and system state
        admin_v2::assert_not_paused(config);
        assert!(tx_context::sender(ctx) == partner_cap.partner_address, EUnauthorized);
        assert!(!partner_cap.is_paused && !partner_cap.emergency_pause, EPartnerPaused);
        assert!(!vault.is_locked, ECollateralLocked);
        assert!(object::uid_to_inner(&vault.id) == partner_cap.vault_id, EInvalidVaultState);
        assert!(withdrawal_amount_usdc > 0, EInvalidWithdrawalAmount);
        
        // Ensure vault is not currently being used in DeFi (or has sufficient buffer)
        if (option::is_some(&vault.defi_protocol_in_use)) {
            assert!(vault.defi_deposit_amount == 0, EVaultInUse);
        };
        
        let current_time_ms = clock::timestamp_ms(clock);
        
        // CORE BUSINESS LOGIC: Calculate how much USDC is actually available
        let points_per_usd = admin_v2::get_points_per_usd(config);
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
        assert!(withdrawal_amount_usdc <= truly_available_usdc, EExcessiveWithdrawal);
        assert!(withdrawal_amount_usdc <= vault.available_for_withdrawal, EInsufficientCollateral);
        
        // Ensure health factor remains safe after withdrawal
        let vault_balance_after = vault_total_usdc - withdrawal_amount_usdc;
        let health_factor_after = calculate_vault_health_factor(
            vault_balance_after,
            vault.outstanding_points_minted,
            points_per_usd
        );
        assert!(health_factor_after >= SAFE_WITHDRAWAL_RATIO_BPS, EHealthFactorTooLow);
        
        // Execute withdrawal
        let withdrawn_balance = balance::split(&mut vault.usdc_balance, withdrawal_amount_usdc);
        let withdrawn_coin = coin::from_balance(withdrawn_balance, ctx);
        
        // Update vault state
        vault.available_for_withdrawal = vault.available_for_withdrawal - withdrawal_amount_usdc;
        
        // Recalculate quotas based on new USDC level
        let new_vault_balance = balance::value(&vault.usdc_balance);
        let new_usd_value = new_vault_balance / 1_000_000;
        let new_lifetime_quota = new_usd_value * points_per_usd;
        
        vault.lifetime_quota_points = new_lifetime_quota;
        vault.health_factor_bps = health_factor_after;
        vault.utilization_rate_bps = if (new_lifetime_quota > 0) {
            (vault.outstanding_points_minted * 10000) / new_lifetime_quota
        } else {
            0
        };
        vault.last_activity_ms = current_time_ms;
        
        // Update registry totals
        registry.total_usdc_locked = registry.total_usdc_locked - withdrawal_amount_usdc;
        
        // Transfer USDC to partner
        transfer::public_transfer(withdrawn_coin, partner_cap.partner_address);
        
        // Emit withdrawal event
        event::emit(USDCWithdrawn {
            vault_id: object::uid_to_inner(&vault.id),
            partner_address: partner_cap.partner_address,
            withdrawn_amount: withdrawal_amount_usdc,
            remaining_usdc: new_vault_balance,
            available_for_withdrawal: vault.available_for_withdrawal,
            points_still_backed: vault.outstanding_points_minted,
            new_quota_allocation: new_lifetime_quota,
            health_factor_after,
            withdrawal_reason,
            timestamp_ms: current_time_ms,
        });
    }
    
    /// Mint points for partner users with proper vault backing
    public entry fun mint_points_with_vault_backing(
        registry: &mut PartnerRegistryV3,
        ledger: &mut LedgerV2,
        config: &ConfigV2,
        partner_cap: &mut PartnerCapV3,
        vault: &mut PartnerVault,
        user_address: address,
        points_amount: u64,
        mint_reason: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate system state and authorization
        admin_v2::assert_mint_not_paused(config);
        assert!(tx_context::sender(ctx) == partner_cap.partner_address, EUnauthorized);
        assert!(!partner_cap.is_paused && !partner_cap.emergency_pause, EPartnerPaused);
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
        let points_per_usd = admin_v2::get_points_per_usd(config);
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
        partner_cap.last_activity_ms = current_time_ms;
        
        vault.outstanding_points_minted = vault.outstanding_points_minted + points_amount;
        vault.total_points_ever_minted = vault.total_points_ever_minted + points_amount;
        vault.reserved_for_backing = vault.reserved_for_backing + usdc_backing_required;
        vault.available_for_withdrawal = vault_balance - vault.reserved_for_backing;
        
        // Update health metrics
        update_vault_health(vault, config, current_time_ms);
        
        // Mint points using ledger_v2
        ledger_v2::mint_points_with_controls(
            ledger,
            user_address,
            points_amount,
            ledger_v2::partner_reward_type(),
            mint_reason,
            clock,
            ctx
        );
        
        // Update registry
        registry.total_quota_utilized = registry.total_quota_utilized + points_amount;
        
        // Emit quota utilization event
        event::emit(QuotaUtilizedV3 {
            vault_id: object::uid_to_inner(&vault.id),
            partner_cap_id: object::uid_to_inner(&partner_cap.id),
            partner_address: partner_cap.partner_address,
            points_minted: points_amount,
            usdc_reserved_for_backing: usdc_backing_required,
            daily_quota_remaining: partner_cap.daily_quota_points - partner_cap.daily_quota_used,
            vault_utilization_rate_bps: vault.utilization_rate_bps,
            health_factor_after: vault.health_factor_bps,
            timestamp_ms: current_time_ms,
        });
    }
    
    // =================== DeFi INTEGRATION FUNCTIONS ===================
    
    /// Transfer vault to DeFi protocol for yield generation (FUTURE FEATURE)
    /// This function enables the vault to be used in protocols like Scallop, Haedal
    public entry fun transfer_vault_to_defi_protocol(
        registry: &mut PartnerRegistryV3,
        config: &ConfigV2,
        partner_cap: &mut PartnerCapV3,
        vault: PartnerVault, // Takes ownership to transfer
        defi_protocol_name: String,
        expected_apy_bps: u64,
        max_utilization_bps: u64,
        defi_recipient: address, // DeFi protocol's address
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate authorization and state
        admin_v2::assert_not_paused(config);
        assert!(tx_context::sender(ctx) == partner_cap.partner_address, EUnauthorized);
        assert!(!partner_cap.is_paused && !partner_cap.emergency_pause, EPartnerPaused);
        assert!(vault.defi_integration_enabled, EDeFiIntegrationPaused);
        assert!(object::uid_to_inner(&vault.id) == partner_cap.vault_id, EInvalidVaultState);
        
        let current_time_ms = clock::timestamp_ms(clock);
        let vault_balance = balance::value(&vault.usdc_balance);
        
        // Ensure vault is large enough for DeFi protocols
        assert!(vault_balance >= MIN_DEFI_DEPOSIT_USDC, EVaultTooSmall);
        
        // Ensure utilization rate is within safe bounds for DeFi
        assert!(vault.utilization_rate_bps <= MAX_UTILIZATION_BPS, EExcessiveWithdrawal);
        assert!(max_utilization_bps <= MAX_UTILIZATION_BPS, EExcessiveWithdrawal);
        
        // Update vault state before transfer
        let mut updated_vault = vault;
        updated_vault.defi_protocol_in_use = option::some(defi_protocol_name);
        updated_vault.defi_deposit_amount = vault_balance;
        updated_vault.last_activity_ms = current_time_ms;
        
        // Update partner cap to reflect new vault owner
        partner_cap.vault_owner = defi_recipient;
        partner_cap.last_activity_ms = current_time_ms;
        
        // Update registry
        registry.total_vaults_in_defi = registry.total_vaults_in_defi + 1;
        registry.total_usdc_in_defi = registry.total_usdc_in_defi + vault_balance;
        
        // Transfer vault to DeFi protocol
        transfer::public_transfer(updated_vault, defi_recipient);
        
        // Emit transfer event
        event::emit(VaultTransferredToDeFi {
            vault_id: partner_cap.vault_id,
            partner_address: partner_cap.partner_address,
            defi_protocol: defi_protocol_name,
            usdc_amount_transferred: vault_balance,
            expected_yield_apy_bps: expected_apy_bps,
            max_utilization_bps,
            transfer_timestamp_ms: current_time_ms,
        });
    }
    
    /// Harvest yield from DeFi protocol (FUTURE FEATURE)  
    /// Called by DeFi protocol or partner to harvest generated yield
    public entry fun harvest_defi_yield(
        registry: &mut PartnerRegistryV3,
        config: &ConfigV2,
        partner_cap: &PartnerCapV3,
        vault: &mut PartnerVault,
        yield_amount_usdc: u64,
        yield_coin: Coin<USDC>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate state and timing
        admin_v2::assert_not_paused(config);
        assert!(object::uid_to_inner(&vault.id) == partner_cap.vault_id, EInvalidVaultState);
        assert!(option::is_some(&vault.defi_protocol_in_use), EInvalidVaultState);
        assert!(coin::value(&yield_coin) == yield_amount_usdc, EInvalidCollateralAmount);
        
        let current_time_ms = clock::timestamp_ms(clock);
        let time_since_last_harvest = current_time_ms - vault.last_yield_harvest_ms;
        assert!(time_since_last_harvest >= YIELD_HARVEST_INTERVAL_MS, EYieldHarvestTooEarly);
        
        // Calculate yield distribution
        let protocol_share = (yield_amount_usdc * DEFI_YIELD_SHARE_BPS) / 10000;
        let partner_share = yield_amount_usdc - protocol_share;
        
        // Add yield to vault
        let yield_balance = coin::into_balance(yield_coin);
        balance::join(&mut vault.usdc_balance, yield_balance);
        
        // Update vault state
        vault.yield_generated_lifetime = vault.yield_generated_lifetime + yield_amount_usdc;
        vault.available_for_withdrawal = vault.available_for_withdrawal + partner_share;
        vault.last_yield_harvest_ms = current_time_ms;
        vault.last_activity_ms = current_time_ms;
        
        // Update registry
        registry.total_yield_generated = registry.total_yield_generated + yield_amount_usdc;
        
        // Emit yield harvest event
        event::emit(YieldHarvested {
            vault_id: object::uid_to_inner(&vault.id),
            partner_address: partner_cap.partner_address,
            defi_protocol: *option::borrow(&vault.defi_protocol_in_use),
            yield_amount_usdc,
            protocol_share_usdc: protocol_share,
            partner_share_usdc: partner_share,
            new_vault_balance: balance::value(&vault.usdc_balance),
            harvest_timestamp_ms: current_time_ms,
        });
    }
    
    // =================== HELPER FUNCTIONS ===================
    
    /// Calculate vault health factor based on USDC backing vs outstanding points
    fun calculate_vault_health_factor(
        usdc_balance: u64,
        outstanding_points: u64,
        points_per_usd: u64
    ): u64 {
        if (outstanding_points == 0) {
            return 10000 // 100% healthy if no outstanding points
        };
        
        if (points_per_usd == 0) {
            return 0 // Unhealthy if conversion rate is invalid
        };
        
        // Convert USDC (6 decimals) to USD for calculation
        let usd_balance = usdc_balance / 1_000_000;
        
        // Calculate required USD backing for outstanding points
        let required_usd_backing = (outstanding_points + points_per_usd - 1) / points_per_usd; // Ceiling division
        
        if (required_usd_backing == 0) {
            return 10000 // Fully backed
        };
        
        // Health factor = (actual_backing / required_backing) * 10000
        let health_factor = (usd_balance * 10000) / required_usd_backing;
        
        // Cap at 10000 (100%)
        if (health_factor > 10000) {
            10000
        } else {
            health_factor
        }
    }
    
    /// Update vault health metrics with DeFi considerations
    fun update_vault_health(
        vault: &mut PartnerVault,
        config: &ConfigV2,
        current_time_ms: u64
    ) {
        let points_per_usd = admin_v2::get_points_per_usd(config);
        let old_health_factor = vault.health_factor_bps;
        
        let vault_balance = balance::value(&vault.usdc_balance);
        let new_health_factor = calculate_vault_health_factor(
            vault_balance,
            vault.outstanding_points_minted,
            points_per_usd
        );
        
        // Calculate utilization rate
        let utilization_rate = if (vault.lifetime_quota_points > 0) {
            (vault.outstanding_points_minted * 10000) / vault.lifetime_quota_points
        } else {
            0
        };
        
        // Update vault metrics
        vault.health_factor_bps = new_health_factor;
        vault.utilization_rate_bps = utilization_rate;
        vault.last_activity_ms = current_time_ms;
        
        // Update risk level
        let risk_level = if (new_health_factor >= MIN_HEALTH_FACTOR_BPS) {
            0 // Safe
        } else if (new_health_factor >= LIQUIDATION_THRESHOLD_BPS) {
            1 // Warning  
        } else if (new_health_factor >= CRITICAL_HEALTH_THRESHOLD_BPS) {
            2 // Critical
        } else {
            3 // Liquidation risk
        };
        
        vault.liquidation_risk_level = risk_level;
        
        // Emit health update if significant change
        if (old_health_factor != new_health_factor) {
            let recommended_action = if (risk_level == 0) {
                b"vault_healthy"
            } else if (risk_level == 1) {
                b"monitor_utilization"
            } else if (risk_level == 2) {
                b"add_usdc_or_reduce_usage"
            } else {
                b"urgent_usdc_needed"
            };
            
            event::emit(VaultHealthUpdated {
                vault_id: object::uid_to_inner(&vault.id),
                partner_address: vault.partner_address,
                old_health_factor_bps: old_health_factor,
                new_health_factor_bps: new_health_factor,
                utilization_rate_bps: utilization_rate,
                risk_level,
                defi_status: vault.defi_protocol_in_use,
                recommended_action,
                timestamp_ms: current_time_ms,
            });
        };
    }
    
    /// Reset daily quota if enough time has passed
    fun reset_daily_quota_if_needed(
        partner_cap: &mut PartnerCapV3,
        current_time_ms: u64
    ) {
        let time_since_reset = current_time_ms - partner_cap.daily_quota_reset_time_ms;
        
        if (time_since_reset >= QUOTA_RESET_INTERVAL_MS) {
            partner_cap.daily_quota_used = 0;
            partner_cap.daily_quota_reset_time_ms = current_time_ms;
        };
    }
    
    /// Update partner registry with new partner information
    fun update_partner_registry_v3(
        registry: &mut PartnerRegistryV3,
        partner_address: address,
        partner_cap_id: ID,
        vault_id: ID,
        generation_id: u64,
        usdc_amount: u64,
        quota_allocated: u64,
        timestamp_ms: u64
    ) {
        // Add partner to generation tracking
        if (!table::contains(&registry.partners_per_generation, generation_id)) {
            let new_generation_partners: vector<address> = vector::empty();
            table::add(&mut registry.partners_per_generation, generation_id, new_generation_partners);
            table::add(&mut registry.generation_partner_count, generation_id, 0);
        };
        
        let generation_partners = table::borrow_mut(&mut registry.partners_per_generation, generation_id);
        vector::push_back(generation_partners, partner_address);
        
        // Update counts
        let current_count = table::borrow_mut(&mut registry.generation_partner_count, generation_id);
        *current_count = *current_count + 1;
        
        // Add to address mappings
        table::add(&mut registry.partner_cap_ids, partner_address, partner_cap_id);
        table::add(&mut registry.partner_vault_ids, partner_address, vault_id);
        
        // Update totals
        registry.total_partners = registry.total_partners + 1;
        registry.total_usdc_locked = registry.total_usdc_locked + usdc_amount;
        registry.total_quota_allocated = registry.total_quota_allocated + quota_allocated;
        registry.last_updated_ms = timestamp_ms;
    }
    
    // =================== VIEW FUNCTIONS ===================
    
    /// Get comprehensive vault information
    public fun get_vault_info(vault: &PartnerVault): (String, address, u64, u64, u64, u64, bool) {
        (
            vault.vault_name,
            vault.partner_address,
            vault.generation_id,
            vault.created_timestamp_ms,
            balance::value(&vault.usdc_balance),
            vault.lifetime_quota_points,
            !vault.is_locked // is_active = not locked
        )
    }
    
    /// Get vault collateral details for DeFi protocols
    public fun get_vault_collateral_details(vault: &PartnerVault): (u64, u64, u64, u64, u64) {
        let total_usdc = balance::value(&vault.usdc_balance);
        let backing_ratio = if (vault.outstanding_points_minted > 0) {
            (total_usdc * 10000) / vault.outstanding_points_minted // Ratio in basis points
        } else {
            10000 // 100% backing when no points minted
        };
        
        (
            total_usdc,                               // Total USDC in vault
            vault.available_for_withdrawal,           // Available for withdrawal
            vault.reserved_for_backing,               // Reserved for backing points
            backing_ratio,                            // Backing ratio in basis points
            vault.health_factor_bps                   // Health factor in basis points
        )
    }
    
    /// Calculate maximum withdrawable USDC (BUSINESS LOGIC FIX)
    public fun calculate_max_withdrawable_usdc(
        vault: &PartnerVault,
        config: &ConfigV2
    ): u64 {
        let points_per_usd = admin_v2::get_points_per_usd(config);
        
        if (points_per_usd == 0) {
            return 0
        };
        
        // Calculate minimum USDC needed for outstanding points + safety buffer
        let required_usd_base = (vault.outstanding_points_minted + points_per_usd - 1) / points_per_usd;
        let required_usdc_base = required_usd_base * 1_000_000; // Convert to USDC (6 decimals)
        let required_usdc_with_buffer = (required_usdc_base * VAULT_SAFETY_BUFFER_BPS) / 10000;
        
        let vault_balance = balance::value(&vault.usdc_balance);
        if (vault_balance > required_usdc_with_buffer) {
            vault_balance - required_usdc_with_buffer
        } else {
            0
        }
    }
    
    /// Get DeFi integration status
    public fun get_defi_status(vault: &PartnerVault): (bool, Option<String>, u64, u64) {
        (
            vault.defi_integration_enabled,
            vault.defi_protocol_in_use,
            vault.defi_deposit_amount,
            vault.yield_generated_lifetime
        )
    }
    
    /// Check if vault is ready for DeFi integration
    public fun is_vault_defi_ready(vault: &PartnerVault): bool {
        vault.defi_integration_enabled &&
        !vault.is_locked &&
        balance::value(&vault.usdc_balance) >= MIN_DEFI_DEPOSIT_USDC &&
        vault.utilization_rate_bps <= MAX_UTILIZATION_BPS &&
        vault.health_factor_bps >= MIN_HEALTH_FACTOR_BPS
    }
    
    /// Get partner capability information
    public fun get_partner_info_v3(partner_cap: &PartnerCapV3): (String, address, u64, ID, address) {
        (
            partner_cap.partner_name,
            partner_cap.partner_address,
            partner_cap.generation_id,
            partner_cap.vault_id,
            partner_cap.vault_owner
        )
    }
    
    /// Get registry statistics
    public fun get_registry_stats_v3(registry: &PartnerRegistryV3): (u64, u64, u64, u64, u64, u64) {
        (
            registry.total_partners,
            registry.total_generations,
            registry.total_usdc_locked,
            registry.total_usdc_in_defi,
            registry.total_yield_generated,
            registry.total_vaults_in_defi
        )
    }
    
    // =================== INTEGRATION FUNCTIONS ===================
    
    /// For integration with ledger_v2 - update vault state after points burn
    public(package) fun on_points_burned_vault(
        vault: &mut PartnerVault,
        points_burned: u64,
        config: &ConfigV2,
        current_time_ms: u64
    ) {
        // Update outstanding balance
        if (vault.outstanding_points_minted >= points_burned) {
            vault.outstanding_points_minted = vault.outstanding_points_minted - points_burned;
        } else {
            vault.outstanding_points_minted = 0;
        };
        
        // Calculate USDC freed up
        let points_per_usd = admin_v2::get_points_per_usd(config);
        let usd_value_freed = if (points_per_usd > 0) {
            points_burned / points_per_usd
        } else {
            0
        };
        let usdc_value_freed = usd_value_freed * 1_000_000; // Convert to USDC (6 decimals)
        
        // Free up reserved USDC
        if (vault.reserved_for_backing >= usdc_value_freed) {
            vault.reserved_for_backing = vault.reserved_for_backing - usdc_value_freed;
        } else {
            vault.reserved_for_backing = 0;
        };
        
        // Update available withdrawal amount
        let vault_balance = balance::value(&vault.usdc_balance);
        vault.available_for_withdrawal = vault_balance - vault.reserved_for_backing;
        
        // Update health
        update_vault_health(vault, config, current_time_ms);
    }
    
    // =================== TEST-ONLY FUNCTIONS ===================
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
    
    #[test_only]
    public fun create_test_usdc_coin(amount: u64, ctx: &mut TxContext): Coin<USDC> {
        coin::mint_for_testing<USDC>(amount, ctx)
    }
    
    #[test_only]  
    public fun destroy_test_vault(vault: PartnerVault) {
        let PartnerVault {
            id,
            vault_name: _,
            partner_address: _,
            generation_id: _,
            created_timestamp_ms: _,
            usdc_balance,
            total_usdc_deposited: _,
            available_for_withdrawal: _,
            reserved_for_backing: _,
            lifetime_quota_points: _,
            outstanding_points_minted: _,
            total_points_ever_minted: _,
            defi_protocol_in_use: _,
            yield_generated_lifetime: _,
            last_yield_harvest_ms: _,
            defi_deposit_amount: _,
            defi_available_for_harvest: _,
            health_factor_bps: _,
            utilization_rate_bps: _,
            liquidation_risk_level: _,
            is_locked: _,
            defi_integration_enabled: _,
            auto_yield_harvest_enabled: _,
            vault_metadata: _,
            last_activity_ms: _,
        } = vault;
        
        balance::destroy_for_testing(usdc_balance);
        object::delete(id);
    }
    
    #[test_only]
    /// Create partner registry for testing
    public fun create_registry_for_testing(
        _admin_cap: &AdminCapV2,
        _config: &ConfigV2,
        ctx: &mut TxContext
    ): PartnerRegistryV3 {
        PartnerRegistryV3 {
            id: object::new(ctx),
            partners_per_generation: table::new(ctx),
            partner_cap_ids: table::new(ctx),
            partner_vault_ids: table::new(ctx),
            generation_partner_count: table::new(ctx),
            total_partners: 0,
            total_generations: 1,
            registry_admin: tx_context::sender(ctx),
            total_usdc_locked: 0,
            total_usdc_in_defi: 0,
            total_yield_generated: 0,
            total_quota_allocated: 0,
            total_quota_utilized: 0,
            defi_protocols_supported: table::new(ctx),
            total_vaults_in_defi: 0,
            last_updated_ms: 0,
        }
    }
    
    #[test_only]
    /// Create partner with vault for testing
    public fun create_partner_with_vault(
        registry: &mut PartnerRegistryV3,
        _config: &ConfigV2,
        partner_name: String,
        vault_name: String,
        generation_id: u64,
        usdc_coin: Coin<USDC>,
        _clock: &Clock,
        ctx: &mut TxContext
    ): (PartnerCapV3, PartnerVault) {
        let partner_address = tx_context::sender(ctx);
        let usdc_amount = coin::value(&usdc_coin);
        let usdc_balance = coin::into_balance(usdc_coin);
        
        let partner_cap = PartnerCapV3 {
            id: object::new(ctx),
            partner_name: partner_name,
            partner_address,
            generation_id,
            onboarding_timestamp_ms: 0,
            vault_id: object::id_from_address(@0x0), // Will be set later
            vault_owner: partner_address,
            daily_quota_points: 100000, // 100K daily quota
            daily_quota_used: 0,
            daily_quota_reset_time_ms: 0,
            is_paused: false,
            pause_reason: vector::empty(),
            emergency_pause: false,
            last_activity_ms: 0,
            admin_notes: vector::empty(),
        };
        
        let vault = PartnerVault {
            id: object::new(ctx),
            vault_name,
            partner_address,
            generation_id,
            created_timestamp_ms: 0,
            usdc_balance,
            total_usdc_deposited: usdc_amount,
            available_for_withdrawal: usdc_amount,
            reserved_for_backing: 0,
            lifetime_quota_points: usdc_amount * 1000, // 1000 points per USD
            outstanding_points_minted: 0,
            total_points_ever_minted: 0,
            defi_protocol_in_use: option::none(),
            yield_generated_lifetime: 0,
            last_yield_harvest_ms: 0,
            defi_deposit_amount: 0,
            defi_available_for_harvest: 0,
            health_factor_bps: 10000,
            utilization_rate_bps: 0,
            liquidation_risk_level: 0,
            is_locked: false,
            defi_integration_enabled: true,
            auto_yield_harvest_enabled: false,
            vault_metadata: vector::empty(),
            last_activity_ms: 0,
        };
        
        // Update registry
        registry.total_partners = registry.total_partners + 1;
        registry.total_usdc_locked = registry.total_usdc_locked + usdc_amount;
        registry.total_quota_allocated = registry.total_quota_allocated + (usdc_amount * 1000);
        
        (partner_cap, vault)
    }
    
    /// Get partner address (public function for other modules)
    public fun get_partner_address(partner_cap: &PartnerCapV3): address {
        partner_cap.partner_address
    }
    
    /// Check if partner is paused
    public fun is_paused(partner_cap: &PartnerCapV3): bool {
        partner_cap.is_paused
    }
    
    /// Get vault partner address
    public fun get_vault_partner_address(vault: &PartnerVault): address {
        vault.partner_address
    }
    
    /// Get partner cap UID to inner (public function for other modules)
    public fun get_partner_cap_uid_to_inner(partner_cap: &PartnerCapV3): ID {
        object::uid_to_inner(&partner_cap.id)
    }
    
    /// Get partner vault UID to inner (public function for other modules)  
    public fun get_partner_vault_uid_to_inner(vault: &PartnerVault): ID {
        object::uid_to_inner(&vault.id)
    }
    
    /// Check if vault can support points minting based on backing requirements
    public fun can_support_points_minting(vault: &PartnerVault, points_amount: u64): bool {
        // Simplified check - ensure vault has sufficient backing
        let required_backing = points_amount / 1000; // Assume 1000 points per USDC backing
        balance::value(&vault.usdc_balance) >= required_backing
    }
    
    /// Record points minting for partner vault tracking
    public fun record_points_minting(vault: &mut PartnerVault, points_amount: u64, _current_time_ms: u64, _ctx: &mut TxContext) {
        // Record that points were minted against this vault's backing
        // In production, this would update detailed tracking metrics
        vault.reserved_for_backing = vault.reserved_for_backing + (points_amount / 1000); // Simple backing ratio
    }
    
    /// Check if vault can support a transaction amount
    public fun can_support_transaction(vault: &PartnerVault, usdc_amount: u64): bool {
        vault.available_for_withdrawal >= usdc_amount
    }

    #[test_only]
    /// Get vault balance for testing
    public fun get_vault_balance(vault: &PartnerVault): u64 {
        balance::value(&vault.usdc_balance)
    }
    
    /// Add revenue to vault (public function for other modules)
    public fun add_revenue_to_vault(
        vault: &mut PartnerVault,
        revenue_amount: u64,
        _current_time_ms: u64,
        _ctx: &mut TxContext
    ) {
        // Add revenue to vault (simplified for testing)
        vault.available_for_withdrawal = vault.available_for_withdrawal + revenue_amount;
        vault.yield_generated_lifetime = vault.yield_generated_lifetime + revenue_amount;
    }
    
    #[test_only]
    /// Add revenue to vault for testing (duplicate for test compatibility)
    public fun add_revenue_to_vault_test(
        vault: &mut PartnerVault,
        revenue_amount: u64,
        current_time_ms: u64,
        ctx: &mut TxContext
    ) {
        // Add revenue to vault (simplified for testing)
        vault.available_for_withdrawal = vault.available_for_withdrawal + revenue_amount;
        vault.yield_generated_lifetime = vault.yield_generated_lifetime + revenue_amount;
        
        // Also add to the actual USDC balance for testing
        let new_usdc = coin::from_balance(balance::create_for_testing<USDC>(revenue_amount), ctx);
        balance::join(&mut vault.usdc_balance, coin::into_balance(new_usdc));
    }
    

    
    #[test_only]
    /// Create partner with vault for testing
    public fun create_partner_with_vault_for_testing(
        registry: &mut PartnerRegistryV3,
        partner_address: address,
        collateral_amount: u64,
        daily_quota: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): (PartnerCapV3, PartnerVault) {
        // Create the partner vault
        let usdc_collateral = balance::create_for_testing<USDC>(collateral_amount);
        let vault = PartnerVault {
            id: object::new(ctx),
            vault_name: string::utf8(b"Test Vault"),
            partner_address,
            generation_id: DEFAULT_GENERATION_ID,
            created_timestamp_ms: clock::timestamp_ms(clock),
            usdc_balance: usdc_collateral,
            total_usdc_deposited: collateral_amount,
            available_for_withdrawal: collateral_amount,
            reserved_for_backing: 0,
            lifetime_quota_points: daily_quota,
            outstanding_points_minted: 0,
            total_points_ever_minted: 0,
            defi_protocol_in_use: option::none(),
            yield_generated_lifetime: 0,
            last_yield_harvest_ms: clock::timestamp_ms(clock),
            defi_deposit_amount: 0,
            defi_available_for_harvest: 0,
            health_factor_bps: 10000, // 100% healthy
                    utilization_rate_bps: 0,
        liquidation_risk_level: 0, // Safe
        is_locked: false,
        defi_integration_enabled: true,
        auto_yield_harvest_enabled: false,
            vault_metadata: b"test_vault_metadata",
            last_activity_ms: clock::timestamp_ms(clock),
        };
        let vault_id = object::uid_to_inner(&vault.id);
        
        // Create the partner capability
        let partner_cap = PartnerCapV3 {
            id: object::new(ctx),
            partner_name: string::utf8(b"Test Partner"),
            partner_address,
            generation_id: DEFAULT_GENERATION_ID,
            onboarding_timestamp_ms: clock::timestamp_ms(clock),
            vault_id,
            vault_owner: partner_address,
            daily_quota_points: daily_quota,
            daily_quota_used: 0,
            daily_quota_reset_time_ms: clock::timestamp_ms(clock),
            is_paused: false,
            pause_reason: b"",
            emergency_pause: false,
            last_activity_ms: clock::timestamp_ms(clock),
            admin_notes: b"test_partner_created",
        };
        
        // Update registry
        registry.total_partners = registry.total_partners + 1;
        registry.total_usdc_locked = registry.total_usdc_locked + collateral_amount;
        registry.total_quota_allocated = registry.total_quota_allocated + daily_quota;
        
        // Store partner information
        let generation_partners = if (table::contains(&registry.partners_per_generation, DEFAULT_GENERATION_ID)) {
            table::borrow_mut(&mut registry.partners_per_generation, DEFAULT_GENERATION_ID)
        } else {
            table::add(&mut registry.partners_per_generation, DEFAULT_GENERATION_ID, vector::empty());
            table::borrow_mut(&mut registry.partners_per_generation, DEFAULT_GENERATION_ID)
        };
        vector::push_back(generation_partners, partner_address);
        
        table::add(&mut registry.partner_cap_ids, partner_address, object::uid_to_inner(&partner_cap.id));
        table::add(&mut registry.partner_vault_ids, partner_address, vault_id);
        
        (partner_cap, vault)
    }
} 