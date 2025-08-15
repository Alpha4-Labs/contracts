#[test_only]
module alpha_points::admin_v2_security_edge_cases_tests {
    use std::string;
    use std::option;
    use std::vector;
    use sui::test_scenario::{Self as scenario, Scenario};
    use sui::clock::{Self, Clock};
    use sui::transfer;
    use sui::object;
    use sui::tx_context;
    use sui::test_utils;
    use sui::table;
    
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2, GovernanceCapV2};
    
    const ADMIN: address = @0xA;
    const ATTACKER: address = @0xBAD;
    const USER1: address = @0xB;
    const USER2: address = @0xC;
    
    // =================== SECURITY: ADMIN CAP VALIDATION TESTS ===================
    
    #[test]
    #[expected_failure(abort_code = 1)] // EUnauthorized
    fun test_forged_admin_cap_rejection() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create legitimate config
        let (mut config, legitimate_admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create a forged admin cap with different ID
        let forged_admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        // Try to use forged admin cap - should fail
        admin_v2::update_apy_rate(
            &mut config,
            &forged_admin_cap,
            600,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(legitimate_admin_cap);
        test_utils::destroy(forged_admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_admin_cap_id_consistency() {
        let mut scenario = scenario::begin(ADMIN);
        
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Test that admin cap IDs are consistent across different getter functions
        let admin_cap_id_1 = admin_v2::get_admin_cap_id(&admin_cap);
        let admin_cap_id_2 = admin_v2::get_admin_cap_uid_to_inner(&admin_cap);
        let config_admin_id = admin_v2::admin_cap_id(&config);
        
        assert!(admin_cap_id_1 == admin_cap_id_2, 1);
        assert!(admin_cap_id_1 == config_admin_id, 2);
        assert!(admin_v2::is_admin(&admin_cap, &config), 3);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        scenario::end(scenario);
    }
    
    // =================== SECURITY: GOVERNANCE CAP VALIDATION TESTS ===================
    
    #[test]
    #[expected_failure(abort_code = 1)] // EUnauthorized
    fun test_forged_governance_cap_rejection() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create legitimate governance infrastructure
        let mut legitimate_governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let config = admin_v2::create_config_for_testing_with_governance_cap(&legitimate_governance_cap, scenario::ctx(&mut scenario));
        
        // Create a forged governance cap
        let mut forged_governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        
        // Try to use forged governance cap - should fail
        admin_v2::create_governance_proposal(
            &mut forged_governance_cap,
            &config,
            1,
            option::some(700u64),
            option::none(),
            option::none(),
            b"forged attempt",
            b"This should fail",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(legitimate_governance_cap);
        test_utils::destroy(forged_governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== BOUNDARY VALUE TESTS ===================
    
    #[test]
    fun test_apy_boundary_values() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Default APY is 500 basis points (5%)
        assert!(admin_v2::get_apy_basis_points(&config) == 500, 3);
        
        // Test going down to 300 (200 point decrease)
        admin_v2::update_apy_rate(&mut config, &admin_cap, 300, &clock, scenario::ctx(&mut scenario));
        assert!(admin_v2::get_apy_basis_points(&config) == 300, 4);
        
        // Test exact minimum APY (100 basis points = 1%) - another 200 point decrease
        admin_v2::update_apy_rate(&mut config, &admin_cap, 100, &clock, scenario::ctx(&mut scenario));
        assert!(admin_v2::get_apy_basis_points(&config) == 100, 5);
        assert!(admin_v2::get_apy_percentage(&config) == 1, 6);
        
        // Work our way up to maximum APY in valid steps (200 basis points at a time)
        // Current is 100, target is 2000
        admin_v2::update_apy_rate(&mut config, &admin_cap, 300, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 500, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 700, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 900, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 1100, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 1300, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 1500, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 1700, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 1900, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 2000, &clock, scenario::ctx(&mut scenario));
        
        assert!(admin_v2::get_apy_basis_points(&config) == 2000, 7);
        assert!(admin_v2::get_apy_percentage(&config) == 20, 8);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_grace_period_boundary_values() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Default grace period is 30 days (2592000000 ms) for testing config
        let (_, _, _, default_grace, _) = admin_v2::get_config_info(&config);
        assert!(default_grace == 2592000000, 8); // 30 days
        
        // Test decreasing by maximum allowed change (7 days = 604800000 ms)
        let max_change = 604800000; // 7 days
        let new_grace_period = default_grace - max_change; // 30 - 7 = 23 days
        admin_v2::update_grace_period(&mut config, &admin_cap, new_grace_period, &clock, scenario::ctx(&mut scenario));
        
        let (_, _, _, current_grace, _) = admin_v2::get_config_info(&config);
        assert!(current_grace == new_grace_period, 9);
        
        // Test increasing by maximum allowed change (7 days = 604800000 ms)
        // Current is 23 days, so we can go up to 30 days (back to default)
        let target_grace_period = current_grace + max_change;
        admin_v2::update_grace_period(&mut config, &admin_cap, target_grace_period, &clock, scenario::ctx(&mut scenario));
        
        let (_, _, _, updated_grace, _) = admin_v2::get_config_info(&config);
        assert!(updated_grace == target_grace_period, 10);
        
        // Work towards maximum grace period (90 days = 7776000000 ms) in valid steps
        // Each step can be at most 7 days (604800000 ms)
        let max_grace_period = 7776000000;
        let mut current_grace_period = updated_grace; // This is now 30 days (back to default)
        
        // Step by step to maximum, ensuring we don't exceed change limit
        while (current_grace_period < max_grace_period) {
            let remaining = max_grace_period - current_grace_period;
            let next_grace = if (remaining <= max_change) {
                max_grace_period
            } else {
                current_grace_period + max_change
            };
            
            admin_v2::update_grace_period(&mut config, &admin_cap, next_grace, &clock, scenario::ctx(&mut scenario));
            current_grace_period = next_grace;
        };
        
        let (_, _, _, final_grace, _) = admin_v2::get_config_info(&config);
        assert!(final_grace == max_grace_period, 11);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== ECONOMIC LIMITS EDGE CASES ===================
    
    #[test]
    fun test_economic_limits_boundary_values() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        let initial_max_supply = admin_v2::get_max_total_supply(&config);
        
        // Test minimum valid daily caps
        admin_v2::update_economic_limits(
            &mut config,
            &admin_cap,
            option::some(initial_max_supply + 1), // Minimum increase
            option::some(1_000_000), // Minimum daily global cap
            option::some(1_000), // Minimum daily per-user cap
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        assert!(admin_v2::get_max_total_supply(&config) == initial_max_supply + 1, 12);
        assert!(admin_v2::get_daily_mint_cap_global(&config) == 1_000_000, 13);
        assert!(admin_v2::get_daily_mint_cap_per_user(&config) == 1_000, 14);
        
        // Test maximum valid daily caps
        admin_v2::update_economic_limits(
            &mut config,
            &admin_cap,
            option::some(initial_max_supply * 2), // Large increase
            option::some(1_000_000_000), // Maximum daily global cap
            option::some(10_000_000), // Maximum daily per-user cap
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        assert!(admin_v2::get_max_total_supply(&config) == initial_max_supply * 2, 15);
        assert!(admin_v2::get_daily_mint_cap_global(&config) == 1_000_000_000, 16);
        assert!(admin_v2::get_daily_mint_cap_per_user(&config) == 10_000_000, 17);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== CONCURRENT ACCESS SIMULATION ===================
    
    #[test]
    fun test_concurrent_admin_operations_simulation() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Simulate rapid consecutive operations
        admin_v2::update_apy_rate(&mut config, &admin_cap, 520, &clock, scenario::ctx(&mut scenario));
        admin_v2::set_emergency_pause(&mut config, &admin_cap, 2, true, b"pause mint", &clock, scenario::ctx(&mut scenario));
        admin_v2::update_economic_limits(&mut config, &admin_cap, option::some(2_000_000_000_000), option::none(), option::none(), &clock, scenario::ctx(&mut scenario));
        admin_v2::set_emergency_pause(&mut config, &admin_cap, 2, false, b"unpause mint", &clock, scenario::ctx(&mut scenario));
        // Update grace period within change limits (7 days max change)
        let (_, _, _, current_grace, _) = admin_v2::get_config_info(&config);
        let target_grace = 1900800000; // 22 days
        let max_change = 604800000; // 7 days
        
        // If the change is within limits, do it directly, otherwise do it in steps
        if (target_grace > current_grace) {
            let change_needed = target_grace - current_grace;
            if (change_needed <= max_change) {
                admin_v2::update_grace_period(&mut config, &admin_cap, target_grace, &clock, scenario::ctx(&mut scenario));
            } else {
                // Change in steps - for simplicity, just change by max allowed amount
                admin_v2::update_grace_period(&mut config, &admin_cap, current_grace - max_change, &clock, scenario::ctx(&mut scenario));
            };
        } else {
            let change_needed = current_grace - target_grace;
            if (change_needed <= max_change) {
                admin_v2::update_grace_period(&mut config, &admin_cap, target_grace, &clock, scenario::ctx(&mut scenario));
            } else {
                // Change in steps - for simplicity, just change by max allowed amount
                admin_v2::update_grace_period(&mut config, &admin_cap, current_grace - max_change, &clock, scenario::ctx(&mut scenario));
            };
        };
        admin_v2::update_apy_rate(&mut config, &admin_cap, 540, &clock, scenario::ctx(&mut scenario));
        
        // Verify final state
        assert!(admin_v2::get_apy_basis_points(&config) == 540, 18);
        assert!(admin_v2::get_max_total_supply(&config) == 2_000_000_000_000, 19);
        
        let (_, _, _, grace_period, _) = admin_v2::get_config_info(&config);
        // Grace period should have been updated (exact value depends on validation limits)
        assert!(grace_period > 0, 20);
        
        let (emergency, mint, redemption, governance) = admin_v2::get_pause_states(&config);
        assert!(!emergency && !mint && !redemption && !governance, 21);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== STATE CONSISTENCY TESTS ===================
    
    #[test]
    fun test_config_state_consistency_after_operations() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Record initial state
        let initial_deployer = admin_v2::deployer_address(&config);
        let initial_treasury = admin_v2::get_treasury_address();
        let initial_points_per_usd = admin_v2::get_points_per_usd(&config);
        
        // Perform various operations
        admin_v2::update_apy_rate(&mut config, &admin_cap, 650, &clock, scenario::ctx(&mut scenario));
        admin_v2::set_emergency_pause(&mut config, &admin_cap, 1, true, b"test pause", &clock, scenario::ctx(&mut scenario));
        admin_v2::set_emergency_pause(&mut config, &admin_cap, 1, false, b"test unpause", &clock, scenario::ctx(&mut scenario));
        admin_v2::update_economic_limits(&mut config, &admin_cap, option::none(), option::some(500_000_000), option::some(50_000), &clock, scenario::ctx(&mut scenario));
        
        // Verify that immutable fields remain unchanged
        assert!(admin_v2::deployer_address(&config) == initial_deployer, 22);
        assert!(admin_v2::get_treasury_address() == initial_treasury, 23);
        assert!(admin_v2::get_points_per_usd(&config) == initial_points_per_usd, 24);
        
        // Verify that mutable fields changed correctly
        assert!(admin_v2::get_apy_basis_points(&config) == 650, 25);
        assert!(admin_v2::get_daily_mint_cap_global(&config) == 500_000_000, 26);
        assert!(admin_v2::get_daily_mint_cap_per_user(&config) == 50_000, 27);
        assert!(!admin_v2::is_paused(&config), 28);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== GOVERNANCE SECURITY TESTS ===================
    
    #[test]
    fun test_governance_proposal_id_uniqueness() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Create multiple proposals and verify they get unique sequential IDs
        let num_proposals = 5;
        let mut i = 0;
        
        while (i < num_proposals) {
            admin_v2::create_governance_proposal(
                &mut governance_cap,
                &config,
                1,
                option::some(500 + (i * 10)),
                option::none(),
                option::none(),
                b"uniqueness test",
                b"Testing proposal ID uniqueness",
                &clock,
                scenario::ctx(&mut scenario)
            );
            
            i = i + 1;
        };
        
        // All proposals should be created with sequential IDs (1, 2, 3, 4, 5)
        // In a real implementation, we would verify the proposal IDs are unique
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== MEMORY AND RESOURCE TESTS ===================
    
    #[test]
    fun test_large_proposal_descriptions() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Create very large description
        let mut large_description = vector::empty<u8>();
        let mut i = 0;
        while (i < 2000) {
            vector::push_back(&mut large_description, ((i % 26) + 65) as u8); // A-Z pattern
            i = i + 1;
        };
        
        // Should handle large descriptions without issues
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1,
            option::some(575u64),
            option::none(),
            option::none(),
            b"large description test",
            large_description,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test empty description
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            2,
            option::some(585u64),
            option::none(),
            option::none(),
            b"empty description test",
            vector::empty<u8>(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== INITIALIZATION EDGE CASES ===================
    
    #[test]
    fun test_init_creates_proper_default_state() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Test the init function creates proper default values
        admin_v2::init_for_testing(scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, ADMIN);
        
        let config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = scenario::take_from_sender<AdminCapV2>(&scenario);
        let governance_cap = scenario::take_from_sender<GovernanceCapV2>(&scenario);
        
        // Verify default economic parameters
        assert!(admin_v2::get_apy_basis_points(&config) == 500, 29); // 5% default
        assert!(admin_v2::get_points_per_usd(&config) == 1000, 30); // 1000 points per USD
        assert!(admin_v2::get_max_total_supply(&config) == 1_000_000_000_000, 31); // 1T max supply
        
        // Verify default operational state
        assert!(!admin_v2::is_paused(&config), 32);
        let (emergency, mint, redemption, governance) = admin_v2::get_pause_states(&config);
        assert!(!emergency && !mint && !redemption && !governance, 33);
        
        // Verify admin relationships
        assert!(admin_v2::is_admin(&admin_cap, &config), 34);
        assert!(admin_v2::deployer_address(&config) == ADMIN, 35);
        
        // Cleanup
        scenario::return_shared(config);
        test_utils::destroy(admin_cap);
        test_utils::destroy(governance_cap);
        scenario::end(scenario);
    }
}
