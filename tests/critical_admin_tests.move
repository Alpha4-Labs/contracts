#[test_only]
#[allow(unused_use, unused_const)]
module alpha_points::critical_admin_tests {
    use sui::test_scenario::{Self as scenario};
    use sui::clock::{Self, Clock};
    use sui::test_utils;
    
    use alpha_points::admin_simple::{Self, ConfigSimple, AdminCapSimple};
    
    const ADMIN: address = @0x123;
    const NON_ADMIN: address = @0x456;
    
    // =================== CRITICAL ADMIN FUNCTIONALITY TESTS ===================
    
    #[test]
    fun test_pause_functionality() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin infrastructure using test helpers
        admin_simple::init_for_testing(scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, ADMIN);
        let admin_cap = scenario::take_from_sender<AdminCapSimple>(&scenario);
        let mut config = scenario::take_shared<ConfigSimple>(&scenario);
        
        // Test initial state - not paused
        assert!(!admin_simple::is_paused(&config), 1);
        admin_simple::assert_not_paused(&config); // Should not abort
        
        // Test pause functionality
        admin_simple::set_emergency_pause(
            &mut config,
            &admin_cap,
            true,
            scenario::ctx(&mut scenario)
        );
        
        // Verify paused state
        assert!(admin_simple::is_paused(&config), 2);
        
        // Test unpause
        admin_simple::set_emergency_pause(
            &mut config,
            &admin_cap,
            false,
            scenario::ctx(&mut scenario)
        );
        
        // Verify unpaused state
        assert!(!admin_simple::is_paused(&config), 3);
        
        // Cleanup
        scenario::return_to_sender(&scenario, admin_cap);
        scenario::return_shared(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_mint_pause_functionality() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin infrastructure
        admin_simple::init_for_testing(scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, ADMIN);
        let admin_cap = scenario::take_from_sender<AdminCapSimple>(&scenario);
        let mut config = scenario::take_shared<ConfigSimple>(&scenario);
        
        // Test initial state - mint not paused
        assert!(!admin_simple::is_mint_paused(&config), 1);
        admin_simple::assert_mint_not_paused(&config); // Should not abort
        
        // Test mint pause functionality
        admin_simple::set_mint_pause(
            &mut config,
            &admin_cap,
            true,
            scenario::ctx(&mut scenario)
        );
        
        // Verify mint paused state
        assert!(admin_simple::is_mint_paused(&config), 2);
        
        // Test mint unpause
        admin_simple::set_mint_pause(
            &mut config,
            &admin_cap,
            false,
            scenario::ctx(&mut scenario)
        );
        
        // Verify mint unpaused state
        assert!(!admin_simple::is_mint_paused(&config), 3);
        
        // Cleanup
        scenario::return_to_sender(&scenario, admin_cap);
        scenario::return_shared(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_admin_authorization() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin infrastructure
        admin_simple::init_for_testing(scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, ADMIN);
        let admin_cap = scenario::take_from_sender<AdminCapSimple>(&scenario);
        let config = scenario::take_shared<ConfigSimple>(&scenario);
        
        // Test admin authorization
        assert!(admin_simple::is_admin(&admin_cap, &config), 1);
        
        // Test admin cap ID functionality
        let cap_id = admin_simple::get_admin_cap_id(&admin_cap);
        assert!(cap_id == admin_simple::get_admin_cap_id(&admin_cap), 2); // ID should be consistent
        
        // Cleanup
        scenario::return_to_sender(&scenario, admin_cap);
        scenario::return_shared(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_config_getters() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create config using test helper
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        
        // Test all getter functions
        let points_per_usd = admin_simple::get_points_per_usd(&config);
        let treasury = admin_simple::get_treasury_address();
        let is_paused = admin_simple::is_paused(&config);
        let is_mint_paused = admin_simple::is_mint_paused(&config);
        
        // Verify expected values
        assert!(points_per_usd == 1000, 1); // 1000 points per USD
        assert!(treasury == @0x999999999999999999999999999999999999999999999999999999999999999, 2);
        assert!(!is_paused, 3);
        assert!(!is_mint_paused, 4);
        
        // Cleanup
        admin_simple::destroy_test_config(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 2)] // EProtocolPaused
    fun test_assert_not_paused_fails_when_paused() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin infrastructure
        admin_simple::init_for_testing(scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, ADMIN);
        let admin_cap = scenario::take_from_sender<AdminCapSimple>(&scenario);
        let mut config = scenario::take_shared<ConfigSimple>(&scenario);
        
        // Pause the protocol
        admin_simple::set_emergency_pause(
            &mut config,
            &admin_cap,
            true,
            scenario::ctx(&mut scenario)
        );
        
        // This should fail
        admin_simple::assert_not_paused(&config);
        
        // Should never reach here
        scenario::return_to_sender(&scenario, admin_cap);
        scenario::return_shared(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 2)] // EProtocolPaused (same as emergency pause)
    fun test_assert_mint_not_paused_fails_when_mint_paused() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin infrastructure
        admin_simple::init_for_testing(scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, ADMIN);
        let admin_cap = scenario::take_from_sender<AdminCapSimple>(&scenario);
        let mut config = scenario::take_shared<ConfigSimple>(&scenario);
        
        // Pause minting
        admin_simple::set_mint_pause(
            &mut config,
            &admin_cap,
            true,
            scenario::ctx(&mut scenario)
        );
        
        // This should fail
        admin_simple::assert_mint_not_paused(&config);
        
        // Should never reach here
        scenario::return_to_sender(&scenario, admin_cap);
        scenario::return_shared(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}
