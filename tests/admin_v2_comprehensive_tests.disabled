#[test_only]
module alpha_points::admin_v2_comprehensive_tests {
    use sui::test_scenario::{Self as scenario};
    use sui::clock;
    use sui::transfer;
    use std::option;
    use std::string;
    use sui::test_utils;
    use sui::object;
    
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2, GovernanceCapV2};
    
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    const GOVERNANCE1: address = @0x1;
    const GOVERNANCE2: address = @0x2;
    
    #[test]
    fun test_comprehensive_getter_functions() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Create admin infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Test getter functions for coverage
        let admin_cap_id = admin_v2::get_admin_cap_id(&admin_cap);
        let admin_cap_uid = admin_v2::get_admin_cap_uid_to_inner(&admin_cap);
        
        // Test that IDs are not zero
        assert!(admin_cap_id != object::id_from_address(@0x0), 28);
        assert!(admin_cap_uid != object::id_from_address(@0x0), 29);
        
        // Test get_config_info - it returns 5 values
        let (config_apy, config_points, config_max, config_daily, config_paused) = admin_v2::get_config_info(&config);
        
        // Verify the returned values
        assert!(config_apy == 500, 30);
        assert!(config_points == 1000, 31);
        assert!(config_max > 0, 32);
        assert!(config_daily > 0, 33);
        assert!(!config_paused, 34);
        
        // Test get_pause_states
        let (pause_state, mint_pause, redemption_pause, governance_pause) = admin_v2::get_pause_states(&config);
        
        // Verify the returned values
        assert!(!pause_state, 35);
        assert!(!mint_pause, 36);
        assert!(!redemption_pause, 37);
        assert!(!governance_pause, 38);
        
        // Test individual getter functions
        let apy_bps = admin_v2::get_apy_basis_points(&config);
        let apy_percentage = admin_v2::get_apy_percentage(&config);
        let points_per_usd = admin_v2::get_points_per_usd(&config);
        let max_supply = admin_v2::get_max_total_supply(&config);
        let daily_global = admin_v2::get_daily_mint_cap_global(&config);
        let daily_user = admin_v2::get_daily_mint_cap_per_user(&config);
        let treasury = admin_v2::get_treasury_address();
        
        // Verify the returned values
        assert!(apy_bps == 500, 39);
        assert!(apy_percentage == 5, 40);
        assert!(points_per_usd == 1000, 41);
        assert!(max_supply > 0, 42);
        assert!(daily_global > 0, 43);
        assert!(daily_user > 0, 44);
        assert!(treasury == @0x999999999999999999999999999999999999999999999999999999999999999, 45);
        
        // Clean up - consume all objects properly
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_comprehensive_admin_operations() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Setup admin infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Test admin cap operations - use functions that actually exist
        let admin_cap_id = admin_v2::get_admin_cap_id(&admin_cap);
        assert!(admin_cap_id != object::id_from_address(@0x0), 46);
        
        // Test config operations - verify config values
        let (apy, points, max_supply, daily_cap, is_paused) = admin_v2::get_config_info(&config);
        assert!(apy == 500, 47);
        assert!(points == 1000, 48);
        assert!(max_supply > 0, 49);
        assert!(daily_cap > 0, 50);
        assert!(!is_paused, 51);
        
        // Clean up - consume all objects properly
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        scenario::end(scenario);
    }
} 