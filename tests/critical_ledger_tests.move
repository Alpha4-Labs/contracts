#[test_only]
#[allow(unused_use, unused_const)]
module alpha_points::critical_ledger_tests {
    use sui::test_scenario::{Self as scenario};
    use sui::clock::{Self, Clock};
    use sui::test_utils;
    
    use alpha_points::admin_simple::{Self, ConfigSimple, AdminCapSimple};
    use alpha_points::ledger_simple::{Self, LedgerSimple};
    
    const ADMIN: address = @0x123;
    const USER1: address = @0x456;
    const USER2: address = @0x789;
    
    // =================== CRITICAL LEDGER FUNCTIONALITY TESTS ===================
    
    #[test]
    fun test_mint_points_functionality() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create test infrastructure
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        let mut ledger = ledger_simple::create_test_ledger(scenario::ctx(&mut scenario));
        
        // Test initial state
        assert!(ledger_simple::get_balance(&ledger, USER1) == 0, 1);
        assert!(ledger_simple::get_total_supply(&ledger) == 0, 2);
        
        // Test minting points
        let mint_amount = 1000;
        ledger_simple::mint_points_for_testing(
            &mut ledger,
            USER1,
            mint_amount
        );
        
        // Verify mint results
        assert!(ledger_simple::get_balance(&ledger, USER1) == mint_amount, 3);
        assert!(ledger_simple::get_total_supply(&ledger) == mint_amount, 4);
        
        // Test minting to different user
        ledger_simple::mint_points_for_testing(
            &mut ledger,
            USER2,
            500
        );
        
        // Verify updated balances
        assert!(ledger_simple::get_balance(&ledger, USER1) == 1000, 5);
        assert!(ledger_simple::get_balance(&ledger, USER2) == 500, 6);
        assert!(ledger_simple::get_total_supply(&ledger) == 1500, 7);
        
        // Cleanup
        admin_simple::destroy_test_config(config);
        ledger_simple::destroy_test_ledger(ledger);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_burn_points_functionality() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create test infrastructure
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        let mut ledger = ledger_simple::create_test_ledger(scenario::ctx(&mut scenario));
        
        // First mint some points
        ledger_simple::mint_points_for_testing(
            &mut ledger,
            USER1,
            1000
        );
        
        // Verify initial state
        assert!(ledger_simple::get_balance(&ledger, USER1) == 1000, 1);
        assert!(ledger_simple::get_total_supply(&ledger) == 1000, 2);
        
        // Test burning points
        ledger_simple::burn_points(
            &mut ledger,
            &config,
            USER1,
            300,
            ledger_simple::user_redemption_type(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify burn results
        assert!(ledger_simple::get_balance(&ledger, USER1) == 700, 3);
        assert!(ledger_simple::get_total_supply(&ledger) == 700, 4);
        
        // Test burning all remaining points
        ledger_simple::burn_points(
            &mut ledger,
            &config,
            USER1,
            700,
            ledger_simple::user_redemption_type(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify complete burn
        assert!(ledger_simple::get_balance(&ledger, USER1) == 0, 5);
        assert!(ledger_simple::get_total_supply(&ledger) == 0, 6);
        
        // Cleanup
        admin_simple::destroy_test_config(config);
        ledger_simple::destroy_test_ledger(ledger);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_balance_and_supply_queries() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create test infrastructure
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        let mut ledger = ledger_simple::create_test_ledger(scenario::ctx(&mut scenario));
        
        // Test initial queries
        assert!(ledger_simple::get_balance(&ledger, USER1) == 0, 1);
        assert!(ledger_simple::get_total_supply(&ledger) == 0, 2);
        
        let (total_supply, _, _) = ledger_simple::get_supply_info(&ledger);
        assert!(total_supply == 0, 3);
        
        // Mint points to multiple users
        ledger_simple::mint_points_for_testing(&mut ledger, USER1, 1000);
        ledger_simple::mint_points_for_testing(&mut ledger, USER2, 2000);
        
        // Test balance queries
        assert!(ledger_simple::get_balance(&ledger, USER1) == 1000, 4);
        assert!(ledger_simple::get_balance(&ledger, USER2) == 2000, 5);
        assert!(ledger_simple::get_balance(&ledger, @0x999) == 0, 6); // Non-existent user
        
        // Test supply queries
        assert!(ledger_simple::get_total_supply(&ledger) == 3000, 7);
        
        let (supply, _, _) = ledger_simple::get_supply_info(&ledger);
        assert!(supply == 3000, 8);
        
        // Cleanup
        admin_simple::destroy_test_config(config);
        ledger_simple::destroy_test_ledger(ledger);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_point_types() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test all point type constants
        let partner_type = ledger_simple::partner_reward_type();
        let perk_type = ledger_simple::perk_redemption_type();
        let admin_type = ledger_simple::admin_mint_type();
        let user_type = ledger_simple::user_redemption_type();
        
        // Verify all types are different
        assert!(partner_type != perk_type, 1);
        assert!(partner_type != admin_type, 2);
        assert!(partner_type != user_type, 3);
        assert!(perk_type != admin_type, 4);
        assert!(perk_type != user_type, 5);
        assert!(admin_type != user_type, 6);
        
        // Cleanup
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_daily_mint_info() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create test infrastructure
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        let ledger = ledger_simple::create_test_ledger(scenario::ctx(&mut scenario));
        
        // Test daily mint info query
        let (daily_minted, daily_cap, last_reset_day) = ledger_simple::get_daily_mint_info(&ledger);
        
        // Verify initial values
        assert!(daily_minted == 0, 1);
        assert!(daily_cap > 0, 2); // Should have some cap
        assert!(last_reset_day == 0, 3); // Initially, should be day 0
        
        // Cleanup
        admin_simple::destroy_test_config(config);
        ledger_simple::destroy_test_ledger(ledger);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 1)] // EInsufficientBalance
    fun test_burn_insufficient_balance() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create test infrastructure
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        let mut ledger = ledger_simple::create_test_ledger(scenario::ctx(&mut scenario));
        
        // Try to burn points without having any - should fail
        ledger_simple::burn_points(
            &mut ledger,
            &config,
            USER1,
            100,
            ledger_simple::user_redemption_type(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_simple::destroy_test_config(config);
        ledger_simple::destroy_test_ledger(ledger);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}
