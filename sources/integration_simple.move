#[allow(duplicate_alias, unused_use, unused_const, unused_function)]
/// Simplified Integration Module - Basic User Endpoints
/// 
/// Core Features:
/// 1. POINT REDEMPTION FOR USDC - Users can redeem points for USDC
/// 2. BASIC USER QUERIES - Balance checks and redemption calculations
/// 3. REMOVED COMPLEXITY - No staking, loans, or complex economic models
/// 4. EMERGENCY PAUSE INTEGRATION - Works with admin_simple
module alpha_points::integration_simple {
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use std::string::{Self, String};
    
    // Import simplified modules
    use alpha_points::admin_simple::{Self, ConfigSimple};
    use alpha_points::ledger_simple::{Self, LedgerSimple};
    use alpha_points::oracle_simple::{Self, OracleSimple};
    
    // USDC Type
    public struct USDC has drop {}
    
    // =================== CONSTANTS ===================
    
    const REDEMPTION_FEE_BPS: u64 = 50;              // 0.5% redemption fee
    const MIN_REDEMPTION_AMOUNT: u64 = 1000;         // 1000 points minimum
    const MAX_REDEMPTION_AMOUNT: u64 = 1000000;      // 1M points maximum per transaction
    
    // =================== ERROR CONSTANTS ===================
    
    const EInsufficientPoints: u64 = 1;
    const EInvalidAmount: u64 = 2;
    #[allow(unused_const)]
    const EProtocolPaused: u64 = 3;
    const EOracleDataStale: u64 = 4;
    const EInsufficientOracleConfidence: u64 = 5;
    
    // =================== EVENTS ===================
    
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
    
    // =================== CORE FUNCTIONS ===================
    
    /// Point redemption (core user function)
    public fun redeem_points_for_usdc(
        config: &ConfigSimple,
        ledger: &mut LedgerSimple,
        oracle: &OracleSimple,
        user_points_amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<USDC> {
        // Basic validations
        admin_simple::assert_not_paused(config);
        let user = tx_context::sender(ctx);
        assert!(user_points_amount >= MIN_REDEMPTION_AMOUNT, EInvalidAmount);
        assert!(user_points_amount <= MAX_REDEMPTION_AMOUNT, EInvalidAmount);
        
        let current_time_ms = clock::timestamp_ms(clock);
        
        // Check user has sufficient points
        let user_balance = ledger_simple::get_balance(ledger, user);
        assert!(user_balance >= user_points_amount, EInsufficientPoints);
        
        // Validate oracle data
        assert!(oracle_simple::is_price_fresh(oracle, string::utf8(b"SUI/USD"), current_time_ms), EOracleDataStale);
        let (sui_price, confidence) = oracle_simple::get_price_with_confidence(oracle, string::utf8(b"SUI/USD"));
        assert!(confidence >= 8000, EInsufficientOracleConfidence); // 80% minimum
        
        // Calculate USDC value and fees
        let (usdc_gross, fee_amount) = calculate_redemption_value(sui_price, user_points_amount);
        let usdc_net = usdc_gross - fee_amount;
        
        // Burn user points
        ledger_simple::burn_points(
            ledger,
            config,
            user,
            user_points_amount,
            ledger_simple::user_redemption_type(),
            clock,
            ctx
        );
        
        // Create USDC coin (in production, this would come from treasury)
        let usdc_coin = coin::zero<USDC>(ctx);
        
        // Emit redemption event
        event::emit(PointsRedeemed {
            user,
            points_amount: user_points_amount,
            usdc_received: usdc_net,
            fee_paid: fee_amount,
            timestamp_ms: current_time_ms,
        });
        
        // Emit user action event
        event::emit(UserAction {
            user,
            action_type: string::utf8(b"redeem_points"),
            points_involved: user_points_amount,
            timestamp_ms: current_time_ms,
        });
        
        usdc_coin
    }
    
    // =================== VIEW FUNCTIONS ===================
    
    /// Get user balance
    public fun get_user_balance(ledger: &LedgerSimple, user: address): u64 {
        ledger_simple::get_balance(ledger, user)
    }
    
    /// Calculate redemption value
    public fun calculate_redemption_value(
        sui_price_8_decimals: u64,
        points_amount: u64
    ): (u64, u64) {
        // Convert points to USD value (1000 points = $1 USD)
        let usd_value_6_decimals = (points_amount * 1_000_000) / 1000; // Convert to USDC (6 decimals)
        
        // Convert USD to USDC using SUI price (simplified conversion)
        let usdc_gross = (usd_value_6_decimals * sui_price_8_decimals) / 100_000_000; // Adjust for price decimals
        
        // Calculate fee
        let fee_amount = (usdc_gross * REDEMPTION_FEE_BPS) / 10000;
        
        (usdc_gross, fee_amount)
    }
    
    /// Check if user can redeem amount
    public fun can_redeem_amount(ledger: &LedgerSimple, user: address, amount: u64): bool {
        if (amount < MIN_REDEMPTION_AMOUNT || amount > MAX_REDEMPTION_AMOUNT) {
            return false
        };
        
        let user_balance = ledger_simple::get_balance(ledger, user);
        user_balance >= amount
    }
    
    // =================== INTERNAL FUNCTIONS ===================
    
    /// Calculate redemption fee
    fun calculate_redemption_fee(usdc_amount: u64): u64 {
        (usdc_amount * REDEMPTION_FEE_BPS) / 10000
    }
    
    /// Validate redemption amount
    fun validate_redemption_amount(points_amount: u64): bool {
        points_amount >= MIN_REDEMPTION_AMOUNT && points_amount <= MAX_REDEMPTION_AMOUNT
    }
    
    // =================== TEST-ONLY FUNCTIONS ===================
    
    #[test_only]
    public fun test_calculate_redemption_value(): (u64, u64) {
        let sui_price = 300_000_000; // $3.00 with 8 decimals
        let points_amount = 3000; // 3000 points = $3.00
        calculate_redemption_value(sui_price, points_amount)
    }
    
    #[test_only]
    public fun create_test_usdc_coin(amount: u64, ctx: &mut TxContext): Coin<USDC> {
        coin::from_balance(sui::balance::create_for_testing<USDC>(amount), ctx)
    }
}
