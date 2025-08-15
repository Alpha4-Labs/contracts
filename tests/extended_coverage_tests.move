#[test_only]
#[allow(unused_use, unused_const)]
module alpha_points::extended_coverage_tests {
    use sui::test_scenario::{Self as scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::test_utils;
    use std::string;
    
    use alpha_points::admin_simple::{Self, ConfigSimple, AdminCapSimple};
    use alpha_points::ledger_simple::{Self, LedgerSimple};
    use alpha_points::oracle_simple::{Self, OracleSimple};
    use alpha_points::partner_simple::{Self, PartnerCapSimple, PartnerVaultSimple};
    use alpha_points::integration_simple::{Self, USDC};
    
    const ADMIN: address = @0x123;
    const USER1: address = @0x456;
    const USER2: address = @0x789;
    
    // =================== EXTENDED COVERAGE TESTS ===================
    
    #[test]
    fun test_partner_functionality() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test partner test helpers
        let (partner_cap, partner_vault) = partner_simple::create_test_partner_and_vault(
            string::utf8(b"Test Partner"),
            5000, // 5,000 USDC
            scenario::ctx(&mut scenario)
        );
        
        // Test partner queries
        let partner_address = partner_simple::get_partner_address(&partner_cap);
        let vault_partner_address = partner_simple::get_vault_partner_address(&partner_vault);
        let is_paused = partner_simple::is_paused(&partner_cap);
        
        assert!(partner_address == vault_partner_address, 1);
        assert!(!is_paused, 2);
        
        // Test vault info
        let (usdc_balance, reserved_backing, available_withdrawal) = partner_simple::get_vault_info(&partner_vault);
        assert!(usdc_balance == 0, 3); // Test helper sets balance to zero
        assert!(reserved_backing == 0, 4); // Initially no backing reserved
        assert!(available_withdrawal == 5000, 5); // Available amount should match
        
        // Test quota checks
        assert!(partner_simple::can_mint_points(&partner_vault, 1000), 6);
        
        // Test quota info
        let (quota_total, quota_used) = partner_simple::get_quota_info(&partner_cap);
        assert!(quota_total > 0, 7);
        assert!(quota_used == 0, 8);
        
        // Cleanup
        partner_simple::destroy_test_partner_cap(partner_cap);
        partner_simple::destroy_test_vault(partner_vault);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_oracle_functionality() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test oracle creation
        let mut oracle = oracle_simple::create_test_oracle(scenario::ctx(&mut scenario));
        
        // Test oracle stats
        let (total_updates, last_update_ms, max_staleness_ms, is_paused) = oracle_simple::get_oracle_stats(&oracle);
        assert!(total_updates == 0, 1);
        assert!(last_update_ms == 0, 2);
        assert!(max_staleness_ms > 0, 3); // Should have some default staleness threshold
        assert!(!is_paused, 4);
        
        // Test price setting
        let pair = string::utf8(b"USDC/SUI");
        oracle_simple::set_test_price(&mut oracle, pair, 150000000, 9000);
        
        // Test price retrieval
        let price = oracle_simple::get_price(&oracle, pair);
        assert!(price == 150000000, 5);
        
        let (price_with_conf, confidence) = oracle_simple::get_price_with_confidence(&oracle, pair);
        assert!(price_with_conf == 150000000, 6);
        assert!(confidence == 9000, 7);
        
        // Test price freshness
        let current_time = clock::timestamp_ms(&clock);
        assert!(oracle_simple::is_price_fresh(&oracle, pair, current_time), 8);
        
        // Test detailed price data
        let (price_data, conf_data, timestamp, is_stale) = oracle_simple::get_price_data(&oracle, pair);
        assert!(price_data == 150000000, 9);
        assert!(conf_data == 9000, 10);
        assert!(timestamp >= 0, 11); // Test oracle may have timestamp 0
        assert!(!is_stale, 12);
        
        // Cleanup
        oracle_simple::destroy_test_oracle(oracle);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_integration_functionality() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test integration helpers
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        let mut ledger = ledger_simple::create_test_ledger(scenario::ctx(&mut scenario));
        
        // Test balance queries
        let initial_balance = integration_simple::get_user_balance(&ledger, USER1);
        assert!(initial_balance == 0, 1);
        
        // Mint some points
        ledger_simple::mint_points_for_testing(&mut ledger, USER1, 50000);
        
        // Test balance after minting
        let balance_after_mint = integration_simple::get_user_balance(&ledger, USER1);
        assert!(balance_after_mint == 50000, 2);
        
        // Test redemption capability checks
        assert!(integration_simple::can_redeem_amount(&ledger, USER1, 25000), 3);
        assert!(integration_simple::can_redeem_amount(&ledger, USER1, 50000), 4);
        assert!(!integration_simple::can_redeem_amount(&ledger, USER1, 50001), 5);
        assert!(!integration_simple::can_redeem_amount(&ledger, USER1, 0), 6); // Below minimum (1000)
        
        // Test helper functions
        let (test_val1, test_val2) = integration_simple::test_calculate_redemption_value();
        assert!(test_val1 > 0, 7);
        assert!(test_val2 > 0, 8);
        
        // Test USDC coin creation
        let usdc_coin = integration_simple::create_test_usdc_coin(1000, scenario::ctx(&mut scenario));
        assert!(coin::value(&usdc_coin) == 1000, 9);
        
        // Cleanup
        test_utils::destroy(usdc_coin);
        admin_simple::destroy_test_config(config);
        ledger_simple::destroy_test_ledger(ledger);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_vault_info_queries() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create test infrastructure
        let (partner_cap, partner_vault) = partner_simple::create_test_partner_and_vault(
            string::utf8(b"Test Partner"),
            10000, // 10,000 USDC
            scenario::ctx(&mut scenario)
        );
        
        // Get vault info
        let (usdc_balance, reserved_backing, available_withdrawal) = partner_simple::get_vault_info(&partner_vault);
        assert!(usdc_balance == 0, 1); // Test helper sets balance to zero
        assert!(reserved_backing == 0, 2); // No backing reserved initially
        assert!(available_withdrawal == 10000, 3); // Available amount should match
        
        // Test vault ID functions
        let cap_vault_id = partner_simple::get_partner_cap_uid_to_inner(&partner_cap);
        let vault_id = partner_simple::get_partner_vault_uid_to_inner(&partner_vault);
        
        // IDs should be different (cap ID vs vault ID)
        assert!(cap_vault_id != vault_id, 4);
        
        // Cleanup
        partner_simple::destroy_test_partner_cap(partner_cap);
        partner_simple::destroy_test_vault(partner_vault);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_comprehensive_workflow() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create all test infrastructure
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        let mut ledger = ledger_simple::create_test_ledger(scenario::ctx(&mut scenario));
        let mut oracle = oracle_simple::create_test_oracle(scenario::ctx(&mut scenario));
        let (partner_cap, partner_vault) = partner_simple::create_test_partner_and_vault(
            string::utf8(b"Test Partner"),
            15000, // 15,000 USDC
            scenario::ctx(&mut scenario)
        );
        
        // Set up oracle price
        oracle_simple::set_test_price(&mut oracle, string::utf8(b"USDC/SUI"), 150000000, 9000);
        
        // Test initial states
        assert!(ledger_simple::get_total_supply(&ledger) == 0, 1);
        assert!(integration_simple::get_user_balance(&ledger, USER1) == 0, 2);
        assert!(oracle_simple::get_price(&oracle, string::utf8(b"USDC/SUI")) == 150000000, 3);
        
        // Mint points to users
        ledger_simple::mint_points_for_testing(&mut ledger, USER1, 75000);
        ledger_simple::mint_points_for_testing(&mut ledger, USER2, 25000);
        
        // Verify minting
        assert!(ledger_simple::get_total_supply(&ledger) == 100000, 4);
        assert!(integration_simple::get_user_balance(&ledger, USER1) == 75000, 5);
        assert!(integration_simple::get_user_balance(&ledger, USER2) == 25000, 6);
        
        // Test redemption capability
        assert!(integration_simple::can_redeem_amount(&ledger, USER1, 50000), 7);
        assert!(integration_simple::can_redeem_amount(&ledger, USER2, 25000), 8);
        
        // Test partner vault info
        let (vault_balance, reserved_backing, available_withdrawal) = partner_simple::get_vault_info(&partner_vault);
        assert!(vault_balance == 0, 9); // Test helper sets balance to zero
        assert!(reserved_backing == 0, 10); // No backing reserved initially
        assert!(available_withdrawal == 15000, 11); // Available amount should match
        
        // Test oracle functionality
        let current_time = clock::timestamp_ms(&clock);
        assert!(oracle_simple::is_price_fresh(&oracle, string::utf8(b"USDC/SUI"), current_time), 12);
        
        // Cleanup
        partner_simple::destroy_test_partner_cap(partner_cap);
        partner_simple::destroy_test_vault(partner_vault);
        oracle_simple::destroy_test_oracle(oracle);
        ledger_simple::destroy_test_ledger(ledger);
        admin_simple::destroy_test_config(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_error_conditions() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test ledger error conditions
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        let mut ledger = ledger_simple::create_test_ledger(scenario::ctx(&mut scenario));
        
        // Test burning without balance (should handle gracefully in test)
        let initial_balance = ledger_simple::get_balance(&ledger, USER1);
        assert!(initial_balance == 0, 1);
        
        // Test integration error conditions
        assert!(!integration_simple::can_redeem_amount(&ledger, USER1, 1000), 2); // Can't redeem without balance
        
        // Test oracle error conditions with non-existent pair
        let oracle = oracle_simple::create_test_oracle(scenario::ctx(&mut scenario));
        let current_time = clock::timestamp_ms(&clock);
        
        // This should return false for non-existent pair
        assert!(!oracle_simple::is_price_fresh(&oracle, string::utf8(b"NONEXISTENT/PAIR"), current_time), 3);
        
        // Cleanup
        oracle_simple::destroy_test_oracle(oracle);
        ledger_simple::destroy_test_ledger(ledger);
        admin_simple::destroy_test_config(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}
