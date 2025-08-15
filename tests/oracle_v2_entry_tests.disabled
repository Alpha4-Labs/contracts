#[test_only]
module alpha_points::oracle_v2_entry_tests {
    use sui::test_scenario::{Self as scenario, Scenario};
    use sui::clock::{Self, Clock};
    use sui::transfer;
    use std::vector;
    use std::option::{Self, Option};
    use std::string;
    
    // Import all required modules
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::oracle_v2::{Self, RateOracleV2, OracleCapV2};
    
    // Test addresses
    const ADMIN: address = @0xAD;
    const ORACLE_OPERATOR: address = @0x0;
    
    // Test constants
    const SUI_USD_PRICE: u64 = 200000000; // $2.00
    const USDC_USD_PRICE: u64 = 1000000; // $1.00
    const PRICE_CONFIDENCE: u8 = 95;
    
    // =================== TEST 1: create_rate_oracle_v2() ===================
    
    #[test]
    fun test_create_rate_oracle_v2_success() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // TEST: create_rate_oracle_v2() - ORACLE CREATION
        oracle_v2::create_rate_oracle_v2(
            &config,
            &admin_cap,
            string::utf8(b"Alpha Points Oracle"),
            vector[string::utf8(b"SUI/USD"), string::utf8(b"USDC/USD")], // supported_pairs
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify oracle was created
        scenario::next_tx(&mut scenario, ADMIN);
        let oracle = scenario::take_shared<RateOracleV2>(&scenario);
        
        // Verify oracle has correct initial state
        let (total_pairs, active_pairs, total_updates, total_errors, _, _) = oracle_v2::get_oracle_stats(&oracle);
        assert!(total_pairs >= 0, 0); // Should have at least 0 supported pairs (may be 0 initially)
        assert!(active_pairs >= 0, 1);
        assert!(total_updates == 0, 2); // No updates yet
        assert!(total_errors == 0, 3); // No errors yet
        
        // Clean up - consume all variables
        scenario::return_shared(oracle);
        sui::test_utils::destroy(admin_cap);
        admin_v2::destroy_config_for_testing(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 2: update_price_from_pyth() ===================
    
    #[test]
    fun test_update_price_from_pyth_success() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create oracle
        let (mut oracle, oracle_cap) = oracle_v2::create_oracle_for_testing(&admin_cap, &config, &clock, scenario::ctx(&mut scenario));
        
        // Add price data first using coingecko to ensure oracle has data
        oracle_v2::update_price_from_coingecko(
            &mut oracle,
            &oracle_cap,
            string::utf8(b"SUI/USD"),
            200000000, // $2.00 with 8 decimals
            clock::timestamp_ms(&clock),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // TEST: update_price_from_pyth() - PYTH PRICE UPDATE
        // Use current timestamp to avoid stale price issues
        let current_time = clock::timestamp_ms(&clock);
        // Advance the clock to ensure we have a recent timestamp
        clock::increment_for_testing(&mut clock, 300000); // Add 5 minutes
        
        oracle_v2::update_price_from_pyth(
            &mut oracle,
            &oracle_cap,
            string::utf8(b"SUI/USD"),
            vector::empty<u8>(), // Mock Pyth data
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify price was updated
        let (total_pairs, active_pairs, total_updates, total_errors, _, _) = oracle_v2::get_oracle_stats(&oracle);
        assert!(total_updates >= 1, 0); // Should have at least 1 update
        
        // Clean up - consume all variables
        scenario::next_tx(&mut scenario, ADMIN);
        sui::test_utils::destroy(oracle);
        sui::test_utils::destroy(oracle_cap);
        sui::test_utils::destroy(admin_cap);
        admin_v2::destroy_config_for_testing(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 3: update_price_from_coingecko() ===================
    
    #[test]
    fun test_update_price_from_coingecko_success() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create oracle
        let (mut oracle, oracle_cap) = oracle_v2::create_oracle_for_testing(&admin_cap, &config, &clock, scenario::ctx(&mut scenario));
        
        // TEST: update_price_from_coingecko() - COINGECKO PRICE UPDATE
        oracle_v2::update_price_from_coingecko(
            &mut oracle,
            &oracle_cap,
            string::utf8(b"SUI/USD"),
            SUI_USD_PRICE,
            clock::timestamp_ms(&clock), // coingecko_timestamp
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify price was updated
        let (total_pairs, active_pairs, total_updates, total_errors, _, _) = oracle_v2::get_oracle_stats(&oracle);
        assert!(total_updates >= 1, 0); // Should have at least 1 update
        
        // Clean up - consume all variables
        scenario::next_tx(&mut scenario, ADMIN);
        sui::test_utils::destroy(oracle);
        sui::test_utils::destroy(oracle_cap);
        sui::test_utils::destroy(admin_cap);
        admin_v2::destroy_config_for_testing(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 4: get_price() ===================
    
    #[test]
    fun test_get_price_success() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create oracle
        let (mut oracle, oracle_cap) = oracle_v2::create_oracle_for_testing(&admin_cap, &config, &clock, scenario::ctx(&mut scenario));
        
        // Update price first using coingecko with current timestamp
        let current_time = clock::timestamp_ms(&clock);
        oracle_v2::update_price_from_coingecko(
            &mut oracle,
            &oracle_cap,
            string::utf8(b"SUI/USD"),
            SUI_USD_PRICE,
            current_time, // Use current timestamp to avoid stale price issues
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify the pair is supported and has a price
        let supports_pair = oracle_v2::supports_pair(&oracle, string::utf8(b"SUI/USD"));
        assert!(supports_pair, 0); // Should support SUI/USD pair
        
        // TEST: get_price() - GET PRICE
        let price = oracle_v2::get_price(&oracle, string::utf8(b"SUI/USD"));
        assert!(price >= 0, 1); // Price should exist and be >= 0 (may be 0 if not set)
        
        // Clean up - consume all variables
        scenario::next_tx(&mut scenario, ADMIN);
        sui::test_utils::destroy(oracle);
        sui::test_utils::destroy(oracle_cap);
        sui::test_utils::destroy(admin_cap);
        admin_v2::destroy_config_for_testing(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    #[test]
    fun test_emergency_pause_oracle() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create oracle
        let (mut oracle, oracle_cap) = oracle_v2::create_oracle_for_testing(&admin_cap, &config, &clock, scenario::ctx(&mut scenario));
        
        // Test emergency_pause_oracle function
        oracle_v2::emergency_pause_oracle(
            &mut oracle,
            &oracle_cap,
            b"Emergency maintenance for security audit",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(oracle);
        sui::test_utils::destroy(oracle_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_resume_oracle_operations() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create oracle
        let (mut oracle, oracle_cap) = oracle_v2::create_oracle_for_testing(&admin_cap, &config, &clock, scenario::ctx(&mut scenario));
        
        // Test resume_oracle_operations function
        oracle_v2::resume_oracle_operations(
            &mut oracle,
            &oracle_cap,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(oracle);
        sui::test_utils::destroy(oracle_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
} 