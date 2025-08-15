/// Module that manages the internal accounting of Alpha Points with correct economic mathematics.
/// Fixed version addressing all critical security vulnerabilities identified in assessment.
/// 
/// Key Fixes:
/// 1. Correct APY-based reward calculations (no more 223x bug)
/// 2. Proper total supply tracking (burns decrease supply)  
/// 3. Comprehensive overflow protection using checked arithmetic
/// 4. Economic safeguards with supply caps and daily limits
/// 5. Single balance system (removed confusing dual system)
/// 6. Clear semantic meaning for all parameters
module alpha_points::ledger_v2 {
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::table::{Self, Table};
    use sui::tx_context::TxContext;
    use sui::object::UID;
    use sui::transfer;
    use std::option::Option;

    
    // Import admin_v2 module for capability checking
    use alpha_points::admin_v2::{AdminCapV2, ConfigV2};
    
    // =================== CONSTANTS ===================
    
    // Economic constants with clear semantics
    const POINTS_PER_USD: u64 = 1000;                    // 1 USD = 1000 Alpha Points (FIXED RATIO)
    const BASIS_POINTS_SCALE: u64 = 10000;               // 10000 basis points = 100%
    const SECONDS_PER_YEAR: u64 = 31557600;              // 365.25 days * 24 * 3600 (includes leap years)
    const MAX_APY_BASIS_POINTS: u64 = 2000;              // Maximum 20% APY allowed
    const MIN_APY_BASIS_POINTS: u64 = 100;               // Minimum 1% APY allowed
    
    // Safety limits to prevent economic exploitation
    const MAX_U64: u64 = 18446744073709551615;           // Maximum u64 value
    const MAX_TOTAL_SUPPLY: u64 = 1000000000000;         // 1 trillion points maximum supply
    const MAX_DAILY_MINT_PER_USER: u64 = 1000000;        // 1 million points per user per day
    const MAX_POINTS_PER_MINT: u64 = 10000000;           // 10 million points per single mint operation
    const DAILY_RESET_INTERVAL_MS: u64 = 86400000;       // 24 hours in milliseconds
    
    // Precision constants for mathematical calculations


    
    // =================== ERROR CONSTANTS ===================
    
    const EInsufficientBalance: u64 = 1;
    const EInsufficientAvailableBalance: u64 = 2;
    const EInsufficientLockedBalance: u64 = 3;
    const EOverflow: u64 = 4;
    const EUnderflow: u64 = 5;
    const EZeroAmount: u64 = 6;
    const ESupplyCapExceeded: u64 = 7;
    const EDailyMintCapExceeded: u64 = 8;
    const EExcessiveMintAmount: u64 = 9;
    const EInvalidAPYRate: u64 = 10;
    const EInvalidTimeParameters: u64 = 11;
    const EProtocolPaused: u64 = 12;
    const EUnauthorized: u64 = 13;
    const EInvalidPriceData: u64 = 14;
    const ECalculationOverflow: u64 = 15;
    
    // =================== STRUCTS ===================
    
    /// Enhanced user balance with available/locked separation and daily tracking
    public struct UserBalance has store {
        available: u64,                 // Points available for use
        locked: u64,                   // Points locked in positions/loans
        daily_minted: u64,             // Points minted today (for rate limiting)
        last_mint_reset_day: u64,      // Last day mint counter was reset
    }
    
    /// Enhanced ledger with proper economic controls and safeguards
    public struct LedgerV2 has key {
        id: UID,
        
        // ===== SUPPLY TRACKING (FIXED) =====
        total_points_minted: u64,      // Total points ever minted
        total_points_burned: u64,      // Total points ever burned (FIXED: now tracked!)
        
        // ===== USER BALANCES =====
        balances: Table<address, UserBalance>,    // Single source of truth for balances
        
        // ===== ECONOMIC PARAMETERS =====
        points_per_usd: u64,           // Conversion rate: 1000 points per $1 USD
        max_total_supply: u64,         // Maximum total supply cap
        default_apy_basis_points: u64, // Default APY in basis points (500 = 5%)
        
        // ===== DAILY LIMITS & RISK MANAGEMENT =====
        daily_mint_cap_per_user: u64,  // Daily minting limit per user
        max_points_per_mint: u64,      // Maximum points per single mint operation
        global_daily_mint_cap: u64,     // Global daily minting limit
        global_daily_minted: u64,      // Points minted globally today
        last_global_reset_day: u64,    // Last day global counter was reset
        
        // ===== EMERGENCY CONTROLS =====
        emergency_pause: bool,         // Emergency pause flag
        mint_pause: bool,              // Minting pause flag
        burn_pause: bool,              // Burning pause flag
        
        // ===== ADMIN ACCESS =====
        admin_cap_id: object::ID,      // Reference to AdminCap for authorization
    }
    
    /// Comprehensive point type categorization for tracking and analytics
    public enum PointType has copy, drop {
        StakingReward,          // Points earned from staking
        LoanCollateral,         // Points minted as loan against collateral
        PartnerReward,          // Points earned through partner programs
        ReferralBonus,          // Points earned from referrals
        LiquidityMining,        // Points earned from providing liquidity
        GovernanceReward,       // Points earned from governance participation
        EmergencyMint,          // Points minted in emergency situations
    }
    
    // Helper functions to create enum variants for external modules
    public fun partner_reward_type(): PointType { PointType::PartnerReward }
    public fun staking_reward_type(): PointType { PointType::StakingReward }
    public fun loan_collateral_type(): PointType { PointType::LoanCollateral }
    public fun referral_bonus_type(): PointType { PointType::ReferralBonus }
    public fun liquidity_mining_type(): PointType { PointType::LiquidityMining }
    public fun governance_reward_type(): PointType { PointType::GovernanceReward }
    public fun emergency_mint_type(): PointType { PointType::EmergencyMint }
    
    // =================== EVENTS ===================
    
    /// Enhanced events with comprehensive tracking information
    public struct PointsMinted has copy, drop {
        user: address,
        amount: u64,
        point_type: PointType,
        new_available_balance: u64,
        new_total_balance: u64,
        total_supply_after: u64,
        daily_user_total: u64,
        timestamp_ms: u64,
        mint_reason: vector<u8>,       // Description of why points were minted
    }
    
    public struct PointsBurned has copy, drop {
        user: address,
        amount: u64,
        new_available_balance: u64,
        new_total_balance: u64,
        total_supply_after: u64,
        timestamp_ms: u64,
        burn_reason: vector<u8>,       // Description of why points were burned
    }
    
    public struct PointsLocked has copy, drop {
        user: address,
        amount: u64,
        new_locked_balance: u64,
        new_available_balance: u64,
        timestamp_ms: u64,
        lock_reason: vector<u8>,
    }
    
    public struct PointsUnlocked has copy, drop {
        user: address,
        amount: u64,
        new_locked_balance: u64,
        new_available_balance: u64,
        timestamp_ms: u64,
        unlock_reason: vector<u8>,
    }
    
    public struct DailyLimitReset has copy, drop {
        user: address,
        previous_daily_total: u64,
        reset_day: u64,
    }
    
    public struct EmergencyAction has copy, drop {
        admin: address,
        action_type: vector<u8>,       // "pause", "unpause", "emergency_mint", etc.
        timestamp_ms: u64,
        details: vector<u8>,
    }
    
    // =================== INITIALIZATION ===================
    
    /// Initialize the enhanced ledger with proper economic parameters
    fun init(ctx: &mut TxContext) {
        let ledger = LedgerV2 {
            id: object::new(ctx),
            
            // Supply tracking
            total_points_minted: 0,
            total_points_burned: 0,
            
            // Balances
            balances: table::new(ctx),
            
            // Economic parameters with safe defaults
            points_per_usd: POINTS_PER_USD,
            max_total_supply: MAX_TOTAL_SUPPLY,
            default_apy_basis_points: 500,  // 5% default APY
            
            // Risk management
            daily_mint_cap_per_user: MAX_DAILY_MINT_PER_USER,
            max_points_per_mint: MAX_POINTS_PER_MINT,
            global_daily_mint_cap: MAX_DAILY_MINT_PER_USER * 1000, // Support 1000 users per day
            global_daily_minted: 0,
            last_global_reset_day: 0,
            
            // Emergency controls
            emergency_pause: false,
            mint_pause: false,
            burn_pause: false,
            
            // Admin access (will be set by admin module)
            admin_cap_id: object::id_from_address(@0x0), // Placeholder
        };
        
        transfer::share_object(ledger);
    }
    
    // =================== CHECKED ARITHMETIC FUNCTIONS ===================
    
    /// Safe addition with overflow checking
    fun safe_add_u64(a: u64, b: u64): u64 {
        let result = (a as u128) + (b as u128);
        assert!(result <= (MAX_U64 as u128), EOverflow);
        (result as u64)
    }
    
    /// Safe subtraction with underflow checking  
    fun safe_sub_u64(a: u64, b: u64): u64 {
        assert!(a >= b, EUnderflow);
        a - b
    }
    

    

    
    // =================== ECONOMIC CALCULATION FUNCTIONS ===================
    
    /// Calculate APY-based rewards with mathematically correct implementation
    /// Fixes the critical 223x multiplier bug from the original implementation
    public fun calculate_apy_rewards(
        principal_usd_value: u64,      // Principal value in USD (with precision, e.g., 3280 = $3.28)
        apy_basis_points: u64,         // APY in basis points (500 = 5%)
        duration_seconds: u64,         // Duration of staking in seconds
        usd_precision: u64             // USD precision factor (1000 for milli-USD)
    ): u64 {
        // Validate inputs
        assert!(apy_basis_points >= MIN_APY_BASIS_POINTS, EInvalidAPYRate);
        assert!(apy_basis_points <= MAX_APY_BASIS_POINTS, EInvalidAPYRate);
        assert!(duration_seconds > 0, EInvalidTimeParameters);
        assert!(usd_precision > 0, EInvalidTimeParameters);
        
        // Convert to high precision arithmetic to avoid overflow/underflow
        let principal_u128 = (principal_usd_value as u128);
        let apy_u128 = (apy_basis_points as u128);
        let duration_u128 = (duration_seconds as u128);
        let year_seconds_u128 = (SECONDS_PER_YEAR as u128);
        let precision_u128 = (usd_precision as u128);
        
        // Calculate: (principal * apy_bps * duration_seconds) / (BASIS_POINTS * SECONDS_PER_YEAR * precision)
        let numerator = principal_u128 * apy_u128 * duration_u128 * (POINTS_PER_USD as u128);
        let denominator = (BASIS_POINTS_SCALE as u128) * year_seconds_u128 * precision_u128;
        
        // Check for calculation overflow
        assert!(numerator / denominator <= (MAX_U64 as u128), ECalculationOverflow);
        
        let usd_rewards = numerator / denominator;
        (usd_rewards as u64)
    }
    
    /// Convert SUI value to USD using oracle price
    public fun convert_sui_to_usd_value(
        sui_amount_mist: u64,           // SUI amount in MIST (1 SUI = 1e9 MIST)
        sui_price_usd_milli: u64        // SUI price in milli-USD (3280 = $3.28)
    ): u64 {
        assert!(sui_price_usd_milli > 0, EInvalidPriceData);
        
        // Convert: (sui_mist * price_milli_usd) / 1e9
        let sui_u128 = (sui_amount_mist as u128);
        let price_u128 = (sui_price_usd_milli as u128);
        let mist_per_sui = 1_000_000_000u128;
        
        let usd_value = (sui_u128 * price_u128) / mist_per_sui;
        assert!(usd_value <= (MAX_U64 as u128), ECalculationOverflow);
        
        (usd_value as u64)
    }
    
    // =================== DAILY LIMIT MANAGEMENT ===================
    
    /// Get current day number (days since epoch)
    fun get_current_day(clock: &Clock): u64 {
        let timestamp_ms = clock::timestamp_ms(clock);
        timestamp_ms / DAILY_RESET_INTERVAL_MS
    }
    
    /// Reset user's daily mint counter if new day
    fun maybe_reset_user_daily_limit(balance: &mut UserBalance, current_day: u64, user: address) {
        if (balance.last_mint_reset_day < current_day) {
            let previous_total = balance.daily_minted;
            balance.daily_minted = 0;
            balance.last_mint_reset_day = current_day;
            
            if (previous_total > 0) {
                event::emit(DailyLimitReset {
                    user,
                    previous_daily_total: previous_total,
                    reset_day: current_day,
                });
            };
        }
    }
    
    /// Reset global daily mint counter if new day
    fun maybe_reset_global_daily_limit(ledger: &mut LedgerV2, current_day: u64) {
        if (ledger.last_global_reset_day < current_day) {
            ledger.global_daily_minted = 0;
            ledger.last_global_reset_day = current_day;
        }
    }
    
    // =================== CORE BALANCE OPERATIONS ===================
    
    /// Enhanced mint function with comprehensive safety checks and economic controls
    public(package) fun mint_points_with_controls(
        ledger: &mut LedgerV2,
        user: address,
        amount: u64,
        point_type: PointType,
        mint_reason: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Basic validations
        assert!(!ledger.emergency_pause, EProtocolPaused);
        assert!(!ledger.mint_pause, EProtocolPaused);
        assert!(amount > 0, EZeroAmount);
        assert!(amount <= ledger.max_points_per_mint, EExcessiveMintAmount);
        
        // Supply cap validation
        let new_total_minted = safe_add_u64(ledger.total_points_minted, amount);
        let current_supply = safe_sub_u64(new_total_minted, ledger.total_points_burned);
        assert!(current_supply <= ledger.max_total_supply, ESupplyCapExceeded);
        
        // Daily limit management
        let current_day = get_current_day(clock);
        maybe_reset_global_daily_limit(ledger, current_day);
        
        // Global daily limit check
        let new_global_daily = safe_add_u64(ledger.global_daily_minted, amount);
        assert!(new_global_daily <= ledger.global_daily_mint_cap, EDailyMintCapExceeded);
        
        // Get or create user balance
        if (!table::contains(&ledger.balances, user)) {
            table::add(&mut ledger.balances, user, UserBalance {
                available: 0,
                locked: 0,
                daily_minted: 0,
                last_mint_reset_day: current_day,
            });
        };
        
        let user_balance = table::borrow_mut(&mut ledger.balances, user);
        
        // Reset user daily limit if needed
        maybe_reset_user_daily_limit(user_balance, current_day, user);
        
        // User daily limit check
        let new_user_daily = safe_add_u64(user_balance.daily_minted, amount);
        assert!(new_user_daily <= ledger.daily_mint_cap_per_user, EDailyMintCapExceeded);
        
        // Update balances
        user_balance.available = safe_add_u64(user_balance.available, amount);
        user_balance.daily_minted = new_user_daily;
        
        // Update ledger totals
        ledger.total_points_minted = new_total_minted;
        ledger.global_daily_minted = new_global_daily;
        
        // Emit comprehensive event
        event::emit(PointsMinted {
            user,
            amount,
            point_type,
            new_available_balance: user_balance.available,
            new_total_balance: safe_add_u64(user_balance.available, user_balance.locked),
            total_supply_after: safe_sub_u64(ledger.total_points_minted, ledger.total_points_burned),
            daily_user_total: user_balance.daily_minted,
            timestamp_ms: clock::timestamp_ms(clock),
            mint_reason,
        });
    }
    
    /// Enhanced burn function with proper supply tracking (FIXES CRITICAL BUG)
    public(package) fun burn_points_with_controls(
        ledger: &mut LedgerV2,
        user: address,
        amount: u64,
        burn_reason: vector<u8>,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        // Basic validations
        assert!(!ledger.emergency_pause, EProtocolPaused);
        assert!(!ledger.burn_pause, EProtocolPaused);
        assert!(amount > 0, EZeroAmount);
        assert!(table::contains(&ledger.balances, user), EInsufficientBalance);
        
        let user_balance = table::borrow_mut(&mut ledger.balances, user);
        assert!(user_balance.available >= amount, EInsufficientAvailableBalance);
        
        // Update user balance
        user_balance.available = safe_sub_u64(user_balance.available, amount);
        
        // CRITICAL FIX: Update total burned supply (was missing in original!)
        ledger.total_points_burned = safe_add_u64(ledger.total_points_burned, amount);
        
        // Emit comprehensive event
        event::emit(PointsBurned {
            user,
            amount,
            new_available_balance: user_balance.available,
            new_total_balance: safe_add_u64(user_balance.available, user_balance.locked),
            total_supply_after: safe_sub_u64(ledger.total_points_minted, ledger.total_points_burned),
            timestamp_ms: clock::timestamp_ms(clock),
            burn_reason,
        });
    }
    
    /// Lock points (move from available to locked)
    public(package) fun lock_points(
        ledger: &mut LedgerV2,
        user: address,
        amount: u64,
        lock_reason: vector<u8>,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(!ledger.emergency_pause, EProtocolPaused);
        assert!(amount > 0, EZeroAmount);
        assert!(table::contains(&ledger.balances, user), EInsufficientBalance);
        
        let user_balance = table::borrow_mut(&mut ledger.balances, user);
        assert!(user_balance.available >= amount, EInsufficientAvailableBalance);
        
        // Transfer from available to locked
        user_balance.available = safe_sub_u64(user_balance.available, amount);
        user_balance.locked = safe_add_u64(user_balance.locked, amount);
        
        event::emit(PointsLocked {
            user,
            amount,
            new_locked_balance: user_balance.locked,
            new_available_balance: user_balance.available,
            timestamp_ms: clock::timestamp_ms(clock),
            lock_reason,
        });
    }
    
    /// Unlock points (move from locked to available)
    public(package) fun unlock_points(
        ledger: &mut LedgerV2,
        user: address,
        amount: u64,
        unlock_reason: vector<u8>,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(!ledger.emergency_pause, EProtocolPaused);
        assert!(amount > 0, EZeroAmount);
        assert!(table::contains(&ledger.balances, user), EInsufficientBalance);
        
        let user_balance = table::borrow_mut(&mut ledger.balances, user);
        assert!(user_balance.locked >= amount, EInsufficientLockedBalance);
        
        // Transfer from locked to available
        user_balance.locked = safe_sub_u64(user_balance.locked, amount);
        user_balance.available = safe_add_u64(user_balance.available, amount);
        
        event::emit(PointsUnlocked {
            user,
            amount,
            new_locked_balance: user_balance.locked,
            new_available_balance: user_balance.available,
            timestamp_ms: clock::timestamp_ms(clock),
            unlock_reason,
        });
    }
    
    // =================== VIEW FUNCTIONS ===================
    
    /// Get user's available balance
    public fun get_available_balance(ledger: &LedgerV2, user: address): u64 {
        if (!table::contains(&ledger.balances, user)) {
            return 0
        };
        let balance = table::borrow(&ledger.balances, user);
        balance.available
    }
    
    /// Get user's locked balance
    public fun get_locked_balance(ledger: &LedgerV2, user: address): u64 {
        if (!table::contains(&ledger.balances, user)) {
            return 0
        };
        let balance = table::borrow(&ledger.balances, user);
        balance.locked
    }
    
    /// Get user's total balance (available + locked)
    public fun get_total_balance(ledger: &LedgerV2, user: address): u64 {
        if (!table::contains(&ledger.balances, user)) {
            return 0
        };
        let balance = table::borrow(&ledger.balances, user);
        safe_add_u64(balance.available, balance.locked)
    }
    
    /// Get user's daily minted amount and remaining daily capacity
    public fun get_daily_mint_info(ledger: &LedgerV2, user: address, clock: &Clock): (u64, u64) {
        if (!table::contains(&ledger.balances, user)) {
            return (0, ledger.daily_mint_cap_per_user)
        };
        
        let balance = table::borrow(&ledger.balances, user);
        let current_day = get_current_day(clock);
        
        // If it's a new day, user gets full daily capacity
        if (balance.last_mint_reset_day < current_day) {
            (0, ledger.daily_mint_cap_per_user)
        } else {
            let remaining = safe_sub_u64(ledger.daily_mint_cap_per_user, balance.daily_minted);
            (balance.daily_minted, remaining)
        }
    }
    
    /// Get actual circulating supply (minted - burned) - FIXED!
    public fun get_actual_supply(ledger: &LedgerV2): u64 {
        safe_sub_u64(ledger.total_points_minted, ledger.total_points_burned)
    }
    
    /// Get total points ever minted
    public fun get_total_minted(ledger: &LedgerV2): u64 {
        ledger.total_points_minted
    }
    
    /// Get total points ever burned
    public fun get_total_burned(ledger: &LedgerV2): u64 {
        ledger.total_points_burned
    }
    
    /// Get comprehensive ledger statistics
    public fun get_ledger_stats(ledger: &LedgerV2): (u64, u64, u64, u64, u64, bool) {
        (
            ledger.total_points_minted,
            ledger.total_points_burned,
            safe_sub_u64(ledger.total_points_minted, ledger.total_points_burned), // circulating supply
            ledger.max_total_supply,
            ledger.global_daily_minted,
            ledger.emergency_pause
        )
    }
    
    // =================== ADMIN FUNCTIONS ===================
    
    /// Set admin cap ID (called by admin module during initialization)
    public(package) fun set_admin_cap_id(ledger: &mut LedgerV2, admin_cap_id: object::ID) {
        ledger.admin_cap_id = admin_cap_id;
    }
    
    /// Emergency pause/unpause (admin only)
    public entry fun set_emergency_pause(
        ledger: &mut LedgerV2,
        admin_cap: &AdminCapV2,
        config: &ConfigV2,
        paused: bool,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Verify admin authorization
        assert!(object::id(admin_cap) == ledger.admin_cap_id, EUnauthorized);
        
        ledger.emergency_pause = paused;
        
        event::emit(EmergencyAction {
            admin: tx_context::sender(ctx),
            action_type: if (paused) b"emergency_pause" else b"emergency_unpause",
            timestamp_ms: clock::timestamp_ms(clock),
            details: b"Emergency pause state changed by admin",
        });
    }
    
    /// Update economic parameters (admin only)
    public entry fun update_economic_parameters(
        ledger: &mut LedgerV2,
        admin_cap: &AdminCapV2,
        config: &ConfigV2,
        mut new_max_supply: Option<u64>,
        mut new_daily_cap_per_user: Option<u64>,
        mut new_max_per_mint: Option<u64>,
        mut new_apy_basis_points: Option<u64>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Verify admin authorization
        assert!(object::id(admin_cap) == ledger.admin_cap_id, EUnauthorized);
        
        // Update parameters if provided
        if (option::is_some(&new_max_supply)) {
            let max_supply = option::extract(&mut new_max_supply);
            assert!(max_supply > ledger.total_points_minted, EInvalidTimeParameters);
            ledger.max_total_supply = max_supply;
        };
        
        if (option::is_some(&new_daily_cap_per_user)) {
            ledger.daily_mint_cap_per_user = option::extract(&mut new_daily_cap_per_user);
        };
        
        if (option::is_some(&new_max_per_mint)) {
            ledger.max_points_per_mint = option::extract(&mut new_max_per_mint);
        };
        
        if (option::is_some(&new_apy_basis_points)) {
            let apy = option::extract(&mut new_apy_basis_points);
            assert!(apy >= MIN_APY_BASIS_POINTS && apy <= MAX_APY_BASIS_POINTS, EInvalidAPYRate);
            ledger.default_apy_basis_points = apy;
        };
        
        event::emit(EmergencyAction {
            admin: tx_context::sender(ctx),
            action_type: b"update_economic_parameters",
            timestamp_ms: clock::timestamp_ms(clock),
            details: b"Economic parameters updated by admin",
        });
    }
    
    // =================== POINT TYPE CONSTRUCTORS ===================
    
    public fun new_staking_reward(): PointType { PointType::StakingReward }
    public fun new_loan_collateral(): PointType { PointType::LoanCollateral }
    public fun new_partner_reward(): PointType { PointType::PartnerReward }
    public fun new_referral_bonus(): PointType { PointType::ReferralBonus }
    public fun new_liquidity_mining(): PointType { PointType::LiquidityMining }
    public fun new_governance_reward(): PointType { PointType::GovernanceReward }
    public fun new_emergency_mint(): PointType { PointType::EmergencyMint }
    
    // =================== TEST-ONLY FUNCTIONS ===================
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
    
    #[test_only]
    public fun test_mint_points(
        ledger: &mut LedgerV2,
        user: address,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        mint_points_with_controls(
            ledger,
            user,
            amount,
            new_staking_reward(),
            b"test_mint",
            clock,
            ctx
        );
    }
    
    #[test_only]
    public fun test_burn_points(
        ledger: &mut LedgerV2,
        user: address,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        burn_points_with_controls(
            ledger,
            user,
            amount,
            b"test_burn",
            clock,
            ctx
        );
    }
    
    #[test_only]
    public fun test_calculate_rewards() {
        // Test the fixed APY calculation
        let principal_usd = 3280; // $3.28 in milli-USD
        let apy_bps = 500; // 5% APY
        let duration_7_days = 7 * 24 * 60 * 60; // 7 days in seconds
        let precision = 1000; // milli-USD precision
        
        let rewards = calculate_apy_rewards(principal_usd, apy_bps, duration_7_days, precision);
        
        // Expected: (3.28 * 0.05 * 7/365.25) * 1000 points/USD ≈ 3.14 points
        // This is VASTLY different from the broken 700+ points from original implementation!
        assert!(rewards >= 3 && rewards <= 4, 999); // Should be around 3-4 points
    }
    
    // =================== ADDITIONAL TEST FUNCTIONS ===================
    
    /// Get user balance (public function for other modules)
    public fun get_balance(ledger: &LedgerV2, user: address): u64 {
        if (table::contains(&ledger.balances, user)) {
            let user_balance = table::borrow(&ledger.balances, user);
            user_balance.available + user_balance.locked
        } else {
            0
        }
    }
    
    #[test_only]
    /// Create ledger for testing
    public fun create_ledger_for_testing(
        admin_cap: &AdminCapV2,
        _config: &ConfigV2,
        ctx: &mut TxContext
    ): LedgerV2 {
        LedgerV2 {
            id: object::new(ctx),
            total_points_minted: 0,
            total_points_burned: 0,
            balances: table::new<address, UserBalance>(ctx),
            points_per_usd: 1000,
            max_total_supply: 1000000000000,
            default_apy_basis_points: 500,
            daily_mint_cap_per_user: 100000,
            max_points_per_mint: 10000000,
            global_daily_mint_cap: 100000000,
            global_daily_minted: 0,
            last_global_reset_day: 0,
            emergency_pause: false,
            mint_pause: false,
            burn_pause: false,
            admin_cap_id: object::id(admin_cap), // Use actual admin cap ID
        }
    }
    
    #[test_only]
    /// Mint points for testing (bypasses normal controls)
    public fun mint_points_for_testing(
        ledger: &mut LedgerV2,
        recipient: address,
        amount: u64,
        _ctx: &mut TxContext
    ) {
        // Add to user balance
        if (table::contains(&ledger.balances, recipient)) {
            let user_balance = table::borrow_mut(&mut ledger.balances, recipient);
            user_balance.available = user_balance.available + amount;
        } else {
            let new_balance = UserBalance {
                available: amount,
                locked: 0,
                daily_minted: amount,
                last_mint_reset_day: 0,
            };
            table::add(&mut ledger.balances, recipient, new_balance);
        };
        
        // Update total supply
        ledger.total_points_minted = ledger.total_points_minted + amount;
        
        // Emit event (using a simplified version for testing)
        event::emit(PointsMinted {
            user: recipient,
            amount,
            point_type: PointType::StakingReward,
            new_total_balance: amount,
            new_available_balance: amount,
            daily_user_total: amount,
            total_supply_after: ledger.total_points_minted,
            timestamp_ms: 0,
            mint_reason: b"testing",
        });
    }
    
    // Removed duplicate burn_points_for_testing function - using the comprehensive version below
    
    #[test_only]
    /// Get total supply for testing
    public fun get_total_supply(ledger: &LedgerV2): u64 {
        ledger.total_points_minted - ledger.total_points_burned
    }
    


    
    #[test_only]
    /// Burn points for testing (bypasses most restrictions)
    public fun burn_points_for_testing(
        ledger: &mut LedgerV2,
        user: address,
        amount: u64,
        reason: vector<u8>,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        // Subtract from user balance
        if (table::contains(&ledger.balances, user)) {
            let user_balance = table::borrow_mut(&mut ledger.balances, user);
            assert!(user_balance.available >= amount, EInsufficientBalance);
            user_balance.available = user_balance.available - amount;
        } else {
            abort EInsufficientBalance
        };
        
        // Update total supply
        ledger.total_points_burned = ledger.total_points_burned + amount;
        
        // Emit event  
        let user_balance_after = get_balance(ledger, user);
        event::emit(PointsBurned {
            user,
            amount,
            burn_reason: reason,
            timestamp_ms: clock::timestamp_ms(clock),
            total_supply_after: get_total_supply(ledger),
            new_available_balance: user_balance_after,
            new_total_balance: user_balance_after,
        });
    }
    
    #[test_only]
    /// Get user balance for testing (duplicate removed - using public function)
    public fun get_balance_test(ledger: &LedgerV2, user: address): u64 {
        get_balance(ledger, user)
    }

    #[test_only]
    /// Create ledger for testing and share it - handles the private transfer internally
    public fun create_ledger_for_testing_and_share(
        admin_cap: &AdminCapV2,
        config: &ConfigV2,
        ctx: &mut TxContext
    ) {
        let ledger = create_ledger_for_testing(admin_cap, config, ctx);
        transfer::share_object(ledger);
    }
} 