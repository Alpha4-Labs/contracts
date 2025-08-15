#[allow(duplicate_alias, unused_use)]
/// Simplified Ledger Module - Pure Point Accounting System
/// 
/// Core Features:
/// 1. SIMPLE POINT MINTING/BURNING - No complex reward calculations
/// 2. BASIC BALANCE TRACKING - Single balance per user, no locked/available split
/// 3. SUPPLY CONTROLS - Total supply caps and daily limits
/// 4. EMERGENCY PAUSE INTEGRATION - Works with admin_simple
/// 5. REMOVED COMPLEXITY - No APY calculations, staking, or loans
module alpha_points::ledger_simple {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::TxContext;
    use sui::transfer;
    use sui::event;
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    
    // Import simplified admin module
    use alpha_points::admin_simple::{Self, ConfigSimple, AdminCapSimple};
    
    // =================== CONSTANTS ===================
    
    // Economic constants
    #[allow(unused_const)]
    const POINTS_PER_USD: u64 = 1000;                    // 1 USD = 1000 Alpha Points
    const MAX_TOTAL_SUPPLY: u64 = 1000000000000;         // 1 trillion points maximum supply
    const MAX_DAILY_MINT_GLOBAL: u64 = 100000000;        // 100M points per day globally
    const MAX_POINTS_PER_MINT: u64 = 10000000;           // 10M points per single mint
    const DAILY_RESET_INTERVAL_MS: u64 = 86400000;       // 24 hours in milliseconds
    
    // =================== ERROR CONSTANTS ===================
    
    const EInsufficientBalance: u64 = 1;
    const EZeroAmount: u64 = 2;
    const ESupplyCapExceeded: u64 = 3;
    const EDailyMintCapExceeded: u64 = 4;
    const EExcessiveMintAmount: u64 = 5;
    #[allow(unused_const)]
    const EProtocolPaused: u64 = 6;
    const EUnauthorized: u64 = 7;
    
    // =================== STRUCTS ===================
    
    /// Simplified ledger - pure accounting, no rewards
    public struct LedgerSimple has key {
        id: UID,
        
        // Supply tracking
        total_points_minted: u64,
        total_points_burned: u64,
        
        // User balances (simplified - just one balance per user)
        balances: Table<address, u64>,     // Simple balance mapping
        
        // Risk management
        max_total_supply: u64,             // 1 trillion points max
        daily_mint_cap_global: u64,        // Global daily limit
        daily_minted_today: u64,           // Today's minted amount
        last_reset_day: u64,               // Last daily reset (days since epoch)
        
        // Admin reference
        admin_cap_id: ID,
    }
    
    /// Simple point type for tracking
    public enum PointType has copy, drop {
        PartnerReward,      // Points from partner actions
        PerkRedemption,     // Points burned for perk redemption  
        AdminMint,          // Admin-minted points
        UserRedemption,     // Points burned for USDC redemption
    }
    
    // Helper functions to create enum variants
    public fun partner_reward_type(): PointType { PointType::PartnerReward }
    public fun perk_redemption_type(): PointType { PointType::PerkRedemption }
    public fun admin_mint_type(): PointType { PointType::AdminMint }
    public fun user_redemption_type(): PointType { PointType::UserRedemption }
    
    // =================== EVENTS ===================
    
    public struct PointsMinted has copy, drop {
        user: address,
        amount: u64,
        point_type: PointType,
        new_balance: u64,
        total_supply_after: u64,
        timestamp_ms: u64,
    }
    
    public struct PointsBurned has copy, drop {
        user: address,
        amount: u64,
        point_type: PointType,
        new_balance: u64,
        total_supply_after: u64,
        timestamp_ms: u64,
    }
    
    public struct DailyLimitsReset has copy, drop {
        reset_day: u64,
        daily_minted_before: u64,
        timestamp_ms: u64,
    }
    
    // =================== INITIALIZATION ===================
    
    /// Initialize the simplified ledger
    fun init(ctx: &mut TxContext) {
        let ledger = LedgerSimple {
            id: object::new(ctx),
            
            // Supply tracking
            total_points_minted: 0,
            total_points_burned: 0,
            
            // Balances
            balances: table::new(ctx),
            
            // Risk management
            max_total_supply: MAX_TOTAL_SUPPLY,
            daily_mint_cap_global: MAX_DAILY_MINT_GLOBAL,
            daily_minted_today: 0,
            last_reset_day: 0,
            
            // Admin access (will be set later)
            admin_cap_id: object::id_from_address(@0x0),
        };
        
        transfer::share_object(ledger);
    }
    
    // =================== CORE OPERATIONS ===================
    
    /// Mint points to a user (used by other modules)
    public fun mint_points(
        ledger: &mut LedgerSimple,
        config: &ConfigSimple,
        user: address, 
        amount: u64,
        point_type: PointType,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        // Basic validations
        admin_simple::assert_mint_not_paused(config);
        assert!(amount > 0, EZeroAmount);
        assert!(amount <= MAX_POINTS_PER_MINT, EExcessiveMintAmount);
        
        let current_time_ms = clock::timestamp_ms(clock);
        
        // Reset daily limits if needed
        reset_daily_limits_if_needed(ledger, current_time_ms);
        
        // Check supply limits
        let new_total_supply = ledger.total_points_minted - ledger.total_points_burned + amount;
        assert!(new_total_supply <= ledger.max_total_supply, ESupplyCapExceeded);
        
        // Check daily limits
        let new_daily_minted = ledger.daily_minted_today + amount;
        assert!(new_daily_minted <= ledger.daily_mint_cap_global, EDailyMintCapExceeded);
        
        // Update ledger state
        ledger.total_points_minted = ledger.total_points_minted + amount;
        ledger.daily_minted_today = new_daily_minted;
        
        // Update user balance
        if (!table::contains(&ledger.balances, user)) {
            table::add(&mut ledger.balances, user, 0);
        };
        let user_balance = table::borrow_mut(&mut ledger.balances, user);
        *user_balance = *user_balance + amount;
        
        // Emit event
        event::emit(PointsMinted {
            user,
            amount,
            point_type,
            new_balance: *user_balance,
            total_supply_after: new_total_supply,
            timestamp_ms: current_time_ms,
        });
    }
    
    /// Burn points from a user (used by other modules)
    public fun burn_points(
        ledger: &mut LedgerSimple,
        config: &ConfigSimple,
        user: address,
        amount: u64,
        point_type: PointType,
        clock: &Clock,
        _ctx: &mut TxContext  
    ) {
        // Basic validations
        admin_simple::assert_not_paused(config);
        assert!(amount > 0, EZeroAmount);
        
        let current_time_ms = clock::timestamp_ms(clock);
        
        // Check user has sufficient balance
        assert!(table::contains(&ledger.balances, user), EInsufficientBalance);
        let user_balance = table::borrow_mut(&mut ledger.balances, user);
        assert!(*user_balance >= amount, EInsufficientBalance);
        
        // Update balances
        *user_balance = *user_balance - amount;
        ledger.total_points_burned = ledger.total_points_burned + amount;
        
        let new_total_supply = ledger.total_points_minted - ledger.total_points_burned;
        
        // Emit event
        event::emit(PointsBurned {
            user,
            amount,
            point_type,
            new_balance: *user_balance,
            total_supply_after: new_total_supply,
            timestamp_ms: current_time_ms,
        });
    }
    
    // =================== VIEW FUNCTIONS ===================
    
    /// Get user balance (used by other modules)
    public fun get_balance(ledger: &LedgerSimple, user: address): u64 {
        if (table::contains(&ledger.balances, user)) {
            *table::borrow(&ledger.balances, user)
        } else {
            0
        }
    }
    
    /// Get total supply (used by other modules)
    public fun get_total_supply(ledger: &LedgerSimple): u64 {
        ledger.total_points_minted - ledger.total_points_burned
    }
    
    /// Get supply info
    public fun get_supply_info(ledger: &LedgerSimple): (u64, u64, u64) {
        (
            ledger.total_points_minted,
            ledger.total_points_burned,
            ledger.total_points_minted - ledger.total_points_burned
        )
    }
    
    /// Get daily mint info
    public fun get_daily_mint_info(ledger: &LedgerSimple): (u64, u64, u64) {
        (
            ledger.daily_minted_today,
            ledger.daily_mint_cap_global,
            ledger.last_reset_day
        )
    }
    
    // =================== INTERNAL FUNCTIONS ===================
    
    /// Reset daily limits if needed
    fun reset_daily_limits_if_needed(ledger: &mut LedgerSimple, current_time_ms: u64) {
        let current_day = current_time_ms / DAILY_RESET_INTERVAL_MS;
        
        if (current_day > ledger.last_reset_day) {
            let old_daily_minted = ledger.daily_minted_today;
            
            ledger.daily_minted_today = 0;
            ledger.last_reset_day = current_day;
            
            event::emit(DailyLimitsReset {
                reset_day: current_day,
                daily_minted_before: old_daily_minted,
                timestamp_ms: current_time_ms,
            });
        };
    }
    
    // =================== ADMIN FUNCTIONS ===================
    
    /// Set admin capability ID (called during setup)
    public fun set_admin_cap_id(
        ledger: &mut LedgerSimple,
        config: &ConfigSimple,
        admin_cap: &AdminCapSimple,
        new_admin_cap_id: ID,
        _ctx: &mut TxContext
    ) {
        assert!(admin_simple::is_admin(admin_cap, config), EUnauthorized);
        ledger.admin_cap_id = new_admin_cap_id;
    }
    
    /// Update daily mint cap
    public entry fun update_daily_mint_cap(
        ledger: &mut LedgerSimple,
        config: &ConfigSimple,
        admin_cap: &AdminCapSimple,
        new_cap: u64,
        _ctx: &mut TxContext
    ) {
        assert!(admin_simple::is_admin(admin_cap, config), EUnauthorized);
        assert!(new_cap > 0 && new_cap <= MAX_DAILY_MINT_GLOBAL * 10, EExcessiveMintAmount);
        
        ledger.daily_mint_cap_global = new_cap;
    }
    
    // =================== TEST-ONLY FUNCTIONS ===================
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
    
    #[test_only]
    public fun create_test_ledger(ctx: &mut TxContext): LedgerSimple {
        LedgerSimple {
            id: object::new(ctx),
            total_points_minted: 0,
            total_points_burned: 0,
            balances: table::new(ctx),
            max_total_supply: MAX_TOTAL_SUPPLY,
            daily_mint_cap_global: MAX_DAILY_MINT_GLOBAL,
            daily_minted_today: 0,
            last_reset_day: 0,
            admin_cap_id: object::id_from_address(@0x0),
        }
    }
    
    #[test_only]
    public fun destroy_test_ledger(ledger: LedgerSimple) {
        let LedgerSimple { 
            id, 
            total_points_minted: _, 
            total_points_burned: _, 
            balances, 
            max_total_supply: _, 
            daily_mint_cap_global: _, 
            daily_minted_today: _, 
            last_reset_day: _,
            admin_cap_id: _
        } = ledger;
        
        table::drop(balances);
        object::delete(id);
    }
    
    #[test_only]
    public fun mint_points_for_testing(
        ledger: &mut LedgerSimple,
        user: address,
        amount: u64
    ) {
        // Add user if not exists
        if (!table::contains(&ledger.balances, user)) {
            table::add(&mut ledger.balances, user, 0);
        };
        
        // Update balances
        let user_balance = table::borrow_mut(&mut ledger.balances, user);
        *user_balance = *user_balance + amount;
        ledger.total_points_minted = ledger.total_points_minted + amount;
    }
}
