#[allow(duplicate_alias, unused_use, unused_const, unused_variable)]
/// Simplified Oracle Module - Basic Price Feed System
/// 
/// Core Features:
/// 1. BASIC PRICE STORAGE - Simple price data without complex validation
/// 2. FRESHNESS VALIDATION - Basic staleness protection
/// 3. CONFIDENCE CHECKS - Minimum confidence thresholds
/// 4. EMERGENCY PAUSE INTEGRATION - Works with admin_simple
/// 5. REMOVED COMPLEXITY - No multi-source validation, failover, or advanced features
module alpha_points::oracle_simple {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use std::string::{Self, String};
    use std::option::Option;
    
    // Import simplified admin module
    use alpha_points::admin_simple::{Self, ConfigSimple, AdminCapSimple};
    
    // =================== CONSTANTS ===================
    
    // Price validation parameters
    const MAX_STALENESS_MS: u64 = 3600000;           // 1 hour max staleness
    const MIN_CONFIDENCE: u64 = 8000;                // 80% minimum confidence (basis points)
    #[allow(unused_const)]
    const PRICE_PRECISION: u64 = 100000000;          // 8 decimal places
    
    // =================== ERROR CONSTANTS ===================
    
    const EUnauthorized: u64 = 1;
    const EPriceStale: u64 = 2;
    const EInsufficientConfidence: u64 = 3;
    const EInvalidPriceData: u64 = 4;
    const EPairNotSupported: u64 = 5;
    const EProtocolPaused: u64 = 6;
    
    // =================== STRUCTS ===================
    
    /// Simplified price data - essential fields only
    public struct PriceDataSimple has store, copy, drop {
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
    
    // =================== EVENTS ===================
    
    public struct PriceUpdated has copy, drop {
        trading_pair: String,
        old_price: u64,
        new_price: u64,
        confidence: u64,
        timestamp_ms: u64,
        price_change_bps: u64,
    }
    
    public struct PriceStaleWarning has copy, drop {
        trading_pair: String,
        price: u64,
        last_update_ms: u64,
        staleness_ms: u64,
        timestamp_ms: u64,
    }
    
    public struct OracleConfigUpdated has copy, drop {
        admin: address,
        max_staleness_ms: u64,
        min_confidence: u64,
        timestamp_ms: u64,
    }
    
    // =================== INITIALIZATION ===================
    
    /// Initialize oracle system
    fun init(_ctx: &mut TxContext) {
        // Oracle instances should be created via create_oracle_simple
    }
    
    /// Create a simple oracle
    public entry fun create_oracle_simple(
        config: &ConfigSimple,
        admin_cap: &AdminCapSimple,
        oracle_name: String,
        supported_pairs: vector<String>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate admin authorization
        assert!(admin_simple::is_admin(admin_cap, config), EUnauthorized);
        assert!(!admin_simple::is_paused(config), EProtocolPaused);
        
        let admin_address = tx_context::sender(ctx);
        let current_time_ms = clock::timestamp_ms(clock);
        
        // Create oracle
        let mut oracle = OracleSimple {
            id: object::new(ctx),
            current_prices: table::new(ctx),
            max_staleness_ms: MAX_STALENESS_MS,
            min_confidence: MIN_CONFIDENCE,
            is_paused: false,
            admin_cap_id: admin_simple::get_admin_cap_id(admin_cap),
            total_updates: 0,
            last_update_ms: current_time_ms,
        };
        
        let oracle_id = object::uid_to_inner(&oracle.id);
        
        // Initialize supported pairs with default prices
        let mut i = 0;
        while (i < vector::length(&supported_pairs)) {
            let pair = *vector::borrow(&supported_pairs, i);
            let default_price = if (pair == string::utf8(b"SUI/USD")) {
                300000000  // $3.00 with 8 decimals
            } else if (pair == string::utf8(b"USDC/USD")) {
                100000000  // $1.00 with 8 decimals
            } else {
                100000000  // Default $1.00
            };
            
            table::add(&mut oracle.current_prices, pair, PriceDataSimple {
                price: default_price,
                confidence: 5000, // 50% confidence (needs update)
                timestamp_ms: current_time_ms,
                is_stale: true,   // Mark as stale initially
            });
            
            i = i + 1;
        };
        
        // Create oracle capability
        let oracle_cap = OracleCapSimple {
            id: object::new(ctx),
            oracle_id,
            can_update_prices: true,
        };
        
        // Share oracle and transfer capability
        transfer::share_object(oracle);
        transfer::public_transfer(oracle_cap, admin_address);
    }
    
    // =================== PRICE OPERATIONS ===================
    
    /// Update price for a trading pair
    public entry fun update_price(
        oracle: &mut OracleSimple,
        oracle_cap: &OracleCapSimple,
        trading_pair: String,
        new_price: u64,
        confidence: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate authorization
        assert!(oracle_cap.oracle_id == object::uid_to_inner(&oracle.id), EUnauthorized);
        assert!(oracle_cap.can_update_prices, EUnauthorized);
        assert!(!oracle.is_paused, EProtocolPaused);
        
        let current_time_ms = clock::timestamp_ms(clock);
        
        // Validate price data
        assert!(new_price > 0, EInvalidPriceData);
        assert!(confidence >= oracle.min_confidence, EInsufficientConfidence);
        assert!(table::contains(&oracle.current_prices, trading_pair), EPairNotSupported);
        
        // Get current price for comparison
        let current_price_data = table::borrow(&oracle.current_prices, trading_pair);
        let old_price = current_price_data.price;
        
        // Calculate price change
        let price_change_bps = if (new_price > old_price) {
            ((new_price - old_price) * 10000) / old_price
        } else {
            ((old_price - new_price) * 10000) / old_price
        };
        
        // Update price data
        let new_price_data = PriceDataSimple {
            price: new_price,
            confidence,
            timestamp_ms: current_time_ms,
            is_stale: false,
        };
        
        table::remove(&mut oracle.current_prices, trading_pair);
        table::add(&mut oracle.current_prices, trading_pair, new_price_data);
        
        // Update oracle stats
        oracle.total_updates = oracle.total_updates + 1;
        oracle.last_update_ms = current_time_ms;
        
        // Emit update event
        event::emit(PriceUpdated {
            trading_pair,
            old_price,
            new_price,
            confidence,
            timestamp_ms: current_time_ms,
            price_change_bps,
        });
    }
    
    // =================== VIEW FUNCTIONS ===================
    
    /// Get current price for a trading pair (used by other modules)
    public fun get_price(oracle: &OracleSimple, trading_pair: String): u64 {
        assert!(table::contains(&oracle.current_prices, trading_pair), EPairNotSupported);
        let price_data = table::borrow(&oracle.current_prices, trading_pair);
        price_data.price
    }
    
    /// Check if price is fresh (used by other modules)
    public fun is_price_fresh(oracle: &OracleSimple, trading_pair: String, current_time: u64): bool {
        if (!table::contains(&oracle.current_prices, trading_pair)) {
            return false
        };
        
        let price_data = table::borrow(&oracle.current_prices, trading_pair);
        let age_ms = current_time - price_data.timestamp_ms;
        age_ms <= oracle.max_staleness_ms && !price_data.is_stale
    }
    
    /// Get price with confidence (used by other modules)
    public fun get_price_with_confidence(oracle: &OracleSimple, trading_pair: String): (u64, u64) {
        assert!(table::contains(&oracle.current_prices, trading_pair), EPairNotSupported);
        let price_data = table::borrow(&oracle.current_prices, trading_pair);
        (price_data.price, price_data.confidence)
    }
    
    /// Get price data details
    public fun get_price_data(oracle: &OracleSimple, trading_pair: String): (u64, u64, u64, bool) {
        assert!(table::contains(&oracle.current_prices, trading_pair), EPairNotSupported);
        let price_data = table::borrow(&oracle.current_prices, trading_pair);
        (price_data.price, price_data.confidence, price_data.timestamp_ms, price_data.is_stale)
    }
    
    /// Get oracle statistics
    public fun get_oracle_stats(oracle: &OracleSimple): (u64, u64, u64, bool) {
        (
            oracle.total_updates,
            oracle.last_update_ms,
            oracle.max_staleness_ms,
            oracle.is_paused
        )
    }
    
    // =================== VALIDATION FUNCTIONS ===================
    
    /// Validate price freshness and emit warning if stale
    public fun validate_and_warn_staleness(
        oracle: &mut OracleSimple,
        trading_pair: String,
        clock: &Clock
    ) {
        if (!table::contains(&oracle.current_prices, trading_pair)) {
            return
        };
        
        let current_time_ms = clock::timestamp_ms(clock);
        let price_data = table::borrow_mut(&mut oracle.current_prices, trading_pair);
        let staleness_ms = current_time_ms - price_data.timestamp_ms;
        
        if (staleness_ms > oracle.max_staleness_ms) {
            price_data.is_stale = true;
            
            event::emit(PriceStaleWarning {
                trading_pair,
                price: price_data.price,
                last_update_ms: price_data.timestamp_ms,
                staleness_ms,
                timestamp_ms: current_time_ms,
            });
        };
    }
    
    // =================== ADMIN FUNCTIONS ===================
    
    /// Update staleness threshold
    public entry fun set_staleness_threshold(
        oracle: &mut OracleSimple,
        oracle_cap: &OracleCapSimple,
        new_threshold_ms: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(oracle_cap.oracle_id == object::uid_to_inner(&oracle.id), EUnauthorized);
        assert!(oracle_cap.can_update_prices, EUnauthorized);
        assert!(new_threshold_ms > 0 && new_threshold_ms <= 86400000, EInvalidPriceData); // Max 24 hours
        
        oracle.max_staleness_ms = new_threshold_ms;
        
        event::emit(OracleConfigUpdated {
            admin: tx_context::sender(ctx),
            max_staleness_ms: new_threshold_ms,
            min_confidence: oracle.min_confidence,
            timestamp_ms: clock::timestamp_ms(clock),
        });
    }
    
    /// Set minimum confidence threshold
    public entry fun set_min_confidence(
        oracle: &mut OracleSimple,
        oracle_cap: &OracleCapSimple,
        new_min_confidence: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(oracle_cap.oracle_id == object::uid_to_inner(&oracle.id), EUnauthorized);
        assert!(oracle_cap.can_update_prices, EUnauthorized);
        assert!(new_min_confidence > 0 && new_min_confidence <= 10000, EInvalidPriceData); // Max 100%
        
        oracle.min_confidence = new_min_confidence;
        
        event::emit(OracleConfigUpdated {
            admin: tx_context::sender(ctx),
            max_staleness_ms: oracle.max_staleness_ms,
            min_confidence: new_min_confidence,
            timestamp_ms: clock::timestamp_ms(clock),
        });
    }
    
    /// Emergency pause oracle
    public entry fun emergency_pause(
        oracle: &mut OracleSimple,
        oracle_cap: &OracleCapSimple,
        paused: bool,
        _ctx: &mut TxContext
    ) {
        assert!(oracle_cap.oracle_id == object::uid_to_inner(&oracle.id), EUnauthorized);
        oracle.is_paused = paused;
    }
    
    // =================== TEST-ONLY FUNCTIONS ===================
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
    
    #[test_only]
    public fun create_test_oracle(ctx: &mut TxContext): OracleSimple {
        let mut oracle = OracleSimple {
            id: object::new(ctx),
            current_prices: table::new(ctx),
            max_staleness_ms: MAX_STALENESS_MS,
            min_confidence: MIN_CONFIDENCE,
            is_paused: false,
            admin_cap_id: object::id_from_address(@0x0),
            total_updates: 0,
            last_update_ms: 0,
        };
        
        // Add default SUI/USD price for testing
        table::add(&mut oracle.current_prices, string::utf8(b"SUI/USD"), PriceDataSimple {
            price: 300000000,  // $3.00
            confidence: 9000,  // 90%
            timestamp_ms: 0,
            is_stale: false,
        });
        
        oracle
    }
    
    #[test_only]
    public fun destroy_test_oracle(oracle: OracleSimple) {
        let OracleSimple { 
            id, 
            current_prices, 
            max_staleness_ms: _, 
            min_confidence: _, 
            is_paused: _, 
            admin_cap_id: _, 
            total_updates: _, 
            last_update_ms: _ 
        } = oracle;
        
        table::drop(current_prices);
        object::delete(id);
    }
    
    #[test_only]
    public fun set_test_price(oracle: &mut OracleSimple, pair: String, price: u64, confidence: u64) {
        if (table::contains(&oracle.current_prices, pair)) {
            table::remove(&mut oracle.current_prices, pair);
        };
        
        table::add(&mut oracle.current_prices, pair, PriceDataSimple {
            price,
            confidence,
            timestamp_ms: 0,
            is_stale: false,
        });
    }
}
