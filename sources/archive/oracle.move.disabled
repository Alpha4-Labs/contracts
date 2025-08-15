/// Module that provides asset price/rate information for Alpha Points against
/// other assets or a base currency like USDC.
module alpha_points::oracle {
    // use sui::object; // Removed as it's a duplicate alias provided by default
    // use sui::tx_context; // Removed as it's a duplicate alias provided by default
    use sui::event;
    use sui::clock::Clock;
    use sui::table::{Self, Table};
    use std::string::String;

    use alpha_points::admin::OracleCap;

    // Error constants
    const EInvalidRate: u64 = 1;
    const EInvalidDecimals: u64 = 2;
    const EOracleStale: u64 = 3;
    const EInvalidEpoch: u64 = 5;

    /// Shared object holding rate information
    public struct RateOracle has key {
        id: object::UID,
        base_rate: u128,          // Fixed-point representation
        decimals: u8,             // Number of decimal places in base_rate
        last_update_epoch: u64,   // When rate was last updated (Consider using Sui Epoch or Timestamp)
        staleness_threshold: u64,  // Max duration (in units matching last_update_epoch) before oracle is considered stale
        oracle_address: address   // Store the authorized oracle address
    }

    // Events
    public struct OracleCreated has copy, drop {
        id: object::ID,
        initial_rate: u128,
        decimals: u8,
        threshold: u64
    }

    public struct RateUpdated has copy, drop {
        id: object::ID,
        old_rate: u128,
        new_rate: u128,
        update_epoch: u64 // Or timestamp if using clock time
    }

    public struct StalenessThresholdUpdated has copy, drop {
        id: object::ID,
        old_threshold: u64,
        new_threshold: u64
    }

    // === External Price Feed Integration ===
    
    /// Structure for external price feed data sources
    public struct ExternalPriceFeed has store {
        api_endpoint: String,        // e.g., "https://api.coingecko.com/api/v3/simple/price"
        asset_symbol: String,        // e.g., "sui" 
        target_currency: String,     // e.g., "usd"
        api_key_required: bool,      // Whether API requires authentication
        update_frequency_epochs: u64, // How often to update (in epochs)
        last_successful_update: u64,  // Last successful update epoch
        backup_feeds: vector<String>, // Backup API endpoints
    }
    
    /// External price oracle for automated SUI price updates
    public struct ExternalPriceOracle has key {
        id: object::UID,
        primary_feed: ExternalPriceFeed,
        authorized_updaters: Table<address, bool>, // Addresses authorized to push price updates
        price_deviation_threshold_bp: u64, // Max price change per update (in basis points)
        auto_update_enabled: bool,
        fallback_manual_mode: bool, // Fall back to manual updates if external feeds fail
    }
    
    /// Create external price oracle for automated SUI price feeds
    public entry fun create_external_price_oracle(
        _oracle_cap: &OracleCap,
        api_endpoint: String,
        asset_symbol: String,
        target_currency: String,
        update_frequency_epochs: u64,
        price_deviation_threshold_bp: u64,
        ctx: &mut tx_context::TxContext
    ) {
        let current_epoch = tx_context::epoch(ctx);
        
        let primary_feed = ExternalPriceFeed {
            api_endpoint,
            asset_symbol,
            target_currency,
            api_key_required: false, // CoinGecko free tier doesn't require API key for basic calls
            update_frequency_epochs,
            last_successful_update: current_epoch,
            backup_feeds: vector[
                std::string::utf8(b"https://api.coinmarketcap.com/v1/cryptocurrency/quotes/latest"),
                std::string::utf8(b"https://api.cryptocompare.com/data/price"),
                std::string::utf8(b"https://api.binance.com/api/v3/ticker/price")
            ]
        };
        
        let mut oracle = ExternalPriceOracle {
            id: object::new(ctx),
            primary_feed,
            authorized_updaters: table::new(ctx),
            price_deviation_threshold_bp,
            auto_update_enabled: true,
            fallback_manual_mode: false
        };
        
        // Authorize the creator as an updater
        table::add(&mut oracle.authorized_updaters, tx_context::sender(ctx), true);
        
        event::emit(ExternalOracleCreated {
            id: object::uid_to_inner(&oracle.id),
            api_endpoint: oracle.primary_feed.api_endpoint,
            asset_symbol: oracle.primary_feed.asset_symbol,
            target_currency: oracle.primary_feed.target_currency,
            update_frequency: update_frequency_epochs
        });
        
        transfer::share_object(oracle);
    }
    
    /// Update rate from external price feed (called by authorized off-chain service)
    /// This replaces the manual update_rate function for automated scenarios
    public entry fun update_rate_from_external_feed(
        external_oracle: &ExternalPriceOracle,
        rate_oracle: &mut RateOracle,
        new_rate: u128,
        price_source: String, // Which API provided this price
        verification_data: String, // Additional verification (timestamp, signature, etc.)
        _clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        let caller = tx_context::sender(ctx);
        assert!(table::contains(&external_oracle.authorized_updaters, caller), EUnauthorizedPriceFeed);
        assert!(external_oracle.auto_update_enabled, EOracleStale);
        
        let current_epoch = tx_context::epoch(ctx);
        
        // Validate price deviation to prevent oracle manipulation
        let old_rate = rate_oracle.base_rate;
        if (old_rate > 0) {
            let price_change_bp = calculate_price_change_bp(old_rate, new_rate);
            assert!(price_change_bp <= external_oracle.price_deviation_threshold_bp, EPriceDeviationTooHigh);
        };
        
        // Update the rate oracle
        let old_rate_for_event = rate_oracle.base_rate;
        rate_oracle.base_rate = new_rate;
        rate_oracle.last_update_epoch = current_epoch;
        
        // Emit comprehensive update event
        event::emit(RateUpdatedFromExternalFeed {
            oracle_id: object::uid_to_inner(&rate_oracle.id),
            external_oracle_id: object::uid_to_inner(&external_oracle.id),
            old_rate: old_rate_for_event,
            new_rate,
            price_source,
            verification_data,
            update_epoch: current_epoch,
            updated_by: caller
        });
    }
    
    /// CoinGecko API integration helper - provides the exact API call format
    /// Example API call for SUI price: https://api.coingecko.com/api/v3/simple/price?ids=sui&vs_currencies=usd
    public fun get_coingecko_api_call_info(): (String, String, String) {
        let api_endpoint = std::string::utf8(b"https://api.coingecko.com/api/v3/simple/price");
        let query_params = std::string::utf8(b"?ids=sui&vs_currencies=usd&include_24hr_change=true&include_last_updated_at=true");
        let headers = std::string::utf8(b"Accept: application/json, User-Agent: Alpha-Points-Oracle/1.0");
        (api_endpoint, query_params, headers)
    }
    
    /// Binance API integration helper for backup price feed
    /// Example: https://api.binance.com/api/v3/ticker/price?symbol=SUIUSDT
    public fun get_binance_api_call_info(): (String, String, String) {
        let api_endpoint = std::string::utf8(b"https://api.binance.com/api/v3/ticker/price");
        let query_params = std::string::utf8(b"?symbol=SUIUSDT");
        let headers = std::string::utf8(b"Accept: application/json");
        (api_endpoint, query_params, headers)
    }
    
    /// CoinMarketCap API integration helper (requires API key)
    public fun get_coinmarketcap_api_call_info(): (String, String, String) {
        let api_endpoint = std::string::utf8(b"https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest");
        let query_params = std::string::utf8(b"?symbol=SUI&convert=USD");
        let headers = std::string::utf8(b"Accept: application/json, X-CMC_PRO_API_KEY: YOUR_API_KEY_HERE");
        (api_endpoint, query_params, headers)
    }
    
    /// Calculate price change in basis points between old and new rates
    fun calculate_price_change_bp(old_rate: u128, new_rate: u128): u64 {
        if (old_rate == 0) return 0;
        
        let rate_diff = if (new_rate > old_rate) {
            new_rate - old_rate
        } else {
            old_rate - new_rate
        };
        
        // Convert to u64 for the calculation, capping if necessary
        let old_rate_u64 = if (old_rate > (18446744073709551615u128)) {
            18446744073709551615u64 // u64::MAX
        } else {
            (old_rate as u64)
        };
        
        let rate_diff_u64 = if (rate_diff > (18446744073709551615u128)) {
            18446744073709551615u64
        } else {
            (rate_diff as u64)
        };
        
        (rate_diff_u64 * 10000) / old_rate_u64
    }
    
    /// Emergency function to disable auto-updates and fall back to manual mode
    public entry fun set_fallback_manual_mode(
        _oracle_cap: &OracleCap,
        external_oracle: &mut ExternalPriceOracle,
        enable_fallback: bool,
        ctx: &mut tx_context::TxContext
    ) {
        external_oracle.fallback_manual_mode = enable_fallback;
        external_oracle.auto_update_enabled = !enable_fallback;
        
        event::emit(OracleModeChanged {
            external_oracle_id: object::uid_to_inner(&external_oracle.id),
            fallback_manual_mode: enable_fallback,
            auto_update_enabled: external_oracle.auto_update_enabled,
            changed_by: tx_context::sender(ctx)
        });
    }
    
    /// Add authorized updater address (for external price feed services)
    public entry fun add_authorized_updater(
        _oracle_cap: &OracleCap,
        external_oracle: &mut ExternalPriceOracle,
        updater_address: address,
        _ctx: &mut tx_context::TxContext
    ) {
        table::add(&mut external_oracle.authorized_updaters, updater_address, true);
        
        event::emit(AuthorizedUpdaterAdded {
            external_oracle_id: object::uid_to_inner(&external_oracle.id),
            updater_address
        });
    }
    
    /// Remove authorized updater
    public entry fun remove_authorized_updater(
        _oracle_cap: &OracleCap,
        external_oracle: &mut ExternalPriceOracle,
        updater_address: address,
        _ctx: &mut tx_context::TxContext
    ) {
        if (table::contains(&external_oracle.authorized_updaters, updater_address)) {
            table::remove(&mut external_oracle.authorized_updaters, updater_address);
        };
        
        event::emit(AuthorizedUpdaterRemoved {
            external_oracle_id: object::uid_to_inner(&external_oracle.id),
            updater_address
        });
    }

    // === Enhanced Events for External Price Feeds ===
    
    public struct ExternalOracleCreated has copy, drop {
        id: object::ID,
        api_endpoint: String,
        asset_symbol: String,
        target_currency: String,
        update_frequency: u64
    }
    
    public struct RateUpdatedFromExternalFeed has copy, drop {
        oracle_id: object::ID,
        external_oracle_id: object::ID,
        old_rate: u128,
        new_rate: u128,
        price_source: String,
        verification_data: String,
        update_epoch: u64,
        updated_by: address
    }
    
    public struct OracleModeChanged has copy, drop {
        external_oracle_id: object::ID,
        fallback_manual_mode: bool,
        auto_update_enabled: bool,
        changed_by: address
    }
    
    public struct AuthorizedUpdaterAdded has copy, drop {
        external_oracle_id: object::ID,
        updater_address: address
    }
    
    public struct AuthorizedUpdaterRemoved has copy, drop {
        external_oracle_id: object::ID,
        updater_address: address
    }

    // === Additional Error Constants ===
    const EUnauthorizedPriceFeed: u64 = 6;
    const EPriceDeviationTooHigh: u64 = 7;

    // === Core module functions ===

    /// Creates and shares RateOracle
    public entry fun create_oracle(
        _oracle_cap: &OracleCap,
        initial_rate: u128,
        decimals: u8,
        threshold: u64,
        ctx: &mut tx_context::TxContext
    ) {
        // Validate inputs
        assert!(initial_rate > 0, EInvalidRate);
        assert!(decimals <= 18, EInvalidDecimals); // Limit max decimals

        // Get the oracle address from the capability owner
        let oracle_address = tx_context::sender(ctx);

        let id = object::new(ctx);
        let oracle_id = object::uid_to_inner(&id); // Get ID for event before potential move

        // Get current epoch for initial update time
        let current_epoch = tx_context::epoch(ctx);

        // Create oracle with initial values
        let oracle = RateOracle {
            id,
            base_rate: initial_rate,
            decimals,
            last_update_epoch: current_epoch, // Setting to current epoch - oracle is fresh at creation
            staleness_threshold: threshold,
            oracle_address
        };

        // Emit event
        event::emit(OracleCreated {
            id: oracle_id,
            initial_rate,
            decimals,
            threshold
        });

        // Share the oracle
        transfer::share_object(oracle);
    }

    /// Updates oracle.base_rate and last_update_epoch
    public entry fun update_rate(
        _oracle_cap: &OracleCap,
        oracle: &mut RateOracle,
        new_rate: u128,
        clock: &Clock,
        ctx: &tx_context::TxContext
    ) {
        assert!(!is_stale(oracle, clock, ctx), EOracleStale);

        let current_epoch = tx_context::epoch(ctx);
        assert!(current_epoch >= oracle.last_update_epoch, EInvalidEpoch);

        let old_rate = oracle.base_rate; // Capture old rate before update

        // Update rate and timestamp/epoch
        oracle.base_rate = new_rate;
        oracle.last_update_epoch = current_epoch;

        // Emit event
        event::emit(RateUpdated {
            id: object::uid_to_inner(&oracle.id),
            old_rate,
            new_rate,
            update_epoch: current_epoch
        });
    }

    /// Updates oracle.staleness_threshold
    public entry fun update_staleness_threshold(
        _oracle_cap: &OracleCap,
        oracle: &mut RateOracle,
        new_threshold: u64,
        clock: &Clock,
        ctx: &tx_context::TxContext
    ) {
        assert!(!is_stale(oracle, clock, ctx), EOracleStale);

        let old_threshold = oracle.staleness_threshold;
        oracle.staleness_threshold = new_threshold;
        
        // Emit event
        event::emit(StalenessThresholdUpdated {
            id: object::uid_to_inner(&oracle.id),
            old_threshold,
            new_threshold
        });
    }

    /// Converts Alpha Points to asset amount using the oracle rate
    public fun convert_points_to_asset(
        points: u64,
        rate: u128,
        decimals: u8
    ): u64 {
        if (points == 0 || rate == 0) {
            return 0
        };

        // Apply rate to points with fixed-point math
        let scaled_points = (points as u128);
        let pow_decimals = pow10(decimals); // Calculate 10^decimals
        // Ensure pow_decimals is not zero to avoid division by zero if decimals is large enough
        // Although u8 limits decimals, making pow10(decimals) unlikely to be zero within u128 range.
        assert!(pow_decimals > 0, EInvalidDecimals); // Or a different error code

        let result = (scaled_points * rate) / pow_decimals;

        // Convert back to u64, capping at u64::MAX if necessary
        let max_u64 = 18446744073709551615u128; // Use constant notation
        if (result > max_u64) {
            (max_u64 as u64) // Return u64::MAX
        } else {
            (result as u64)
        }
    }

    /// Converts asset amount to Alpha Points using the oracle rate
    public fun convert_asset_to_points(
        asset: u64,
        rate: u128,
        decimals: u8
    ): u64 {
        if (asset == 0) { // No need to check rate here, handled below
            return 0
        };
        // Rate must be non-zero for inverse calculation
        assert!(rate > 0, EInvalidRate);

        // Calculate inverse rate and apply to asset with fixed-point math
        let scaled_asset = (asset as u128);
        let pow_decimals = pow10(decimals);
        assert!(pow_decimals > 0, EInvalidDecimals);

        // points = asset * (10^decimals / rate)
        // To prevent potential overflow from scaled_asset * pow_decimals, check intermediate result if needed
        // Or rearrange calculation if possible, but division first might lose precision.
        let result = (scaled_asset * pow_decimals) / rate;

        // Convert back to u64, capping at u64::MAX if necessary
        let max_u64 = 18446744073709551615u128;
        if (result > max_u64) {
            (max_u64 as u64)
        } else {
            (result as u64)
        }
    }

    // === View functions ===

    /// Returns the oracle rate and decimals
    public fun get_rate(oracle: &RateOracle): (u128, u8) {
        (oracle.base_rate, oracle.decimals)
    }

    /// Checks if the oracle data is stale based on the clock time.
    /// Returns true if the oracle is stale, false otherwise.
    public fun is_stale(oracle: &RateOracle, _clock: &Clock, ctx: &tx_context::TxContext): bool {
        // Check if the time elapsed since the last update exceeds the staleness threshold.
        // Assumes last_update_epoch and staleness_threshold are in terms of epochs.
        let current_epoch = tx_context::epoch(ctx);
        current_epoch > oracle.last_update_epoch && (current_epoch - oracle.last_update_epoch) > oracle.staleness_threshold
    }

    /// Returns the staleness threshold
    public fun get_staleness_threshold(oracle: &RateOracle): u64 {
        oracle.staleness_threshold
    }

    /// Asserts that the oracle is not stale. Aborts if it is.
    /// To be used by functions that rely on fresh oracle data.
    public fun assert_not_stale(oracle: &RateOracle, clock: &Clock, ctx: &tx_context::TxContext) {
        assert!(!is_stale(oracle, clock, ctx), EOracleStale);
    }

    // === Helper functions ===

    /// Calculate 10^n
    fun pow10(n: u8): u128 {
        let mut i = 0;
        let mut result = 1u128;

        while (i < n) {
            // Check for potential overflow before multiplication
            // 10 * result > u128::MAX  <=> result > u128::MAX / 10
            let max_div_10 = 34028236692093846346337460743176821145u128; // u128::MAX / 10
            assert!(result <= max_div_10, EInvalidDecimals); // Prevent overflow

            result = result * 10;
            i = i + 1;
        };

        result
    }

    /// Converts an amount of a base asset (whose price is tracked by this oracle)
    /// into its equivalent value in the target currency (e.g., USDC points),
    /// using the oracle's rate and decimals.
    public fun price_in_usdc(oracle: &RateOracle, amount_of_base_asset: u64): u64 {
        if (amount_of_base_asset == 0 || oracle.base_rate == 0) {
            return 0
        };

        // Calculation: (amount_of_base_asset * oracle.base_rate) / 10^oracle.decimals
        // This is effectively the same as convert_points_to_asset if we consider
        // 'amount_of_base_asset' as 'points' and 'oracle.base_rate' as 'rate'.
        let scaled_amount = (amount_of_base_asset as u128);
        let pow_decimals = pow10(oracle.decimals);
        assert!(pow_decimals > 0, EInvalidDecimals); // Should be handled by pow10's own assert for large n

        let result = (scaled_amount * oracle.base_rate) / pow_decimals;

        // Convert back to u64, capping at u64::MAX if necessary
        let max_u64 = 18446744073709551615u128; // u64::MAX
        if (result > max_u64) {
            (max_u64 as u64)
        } else {
            (result as u64)
        }
    }
}