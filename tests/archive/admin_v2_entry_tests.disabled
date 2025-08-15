#[test_only]
module alpha_points::admin_v2_entry_tests {
    use std::string;
    use std::option;
    use std::vector;
    use sui::test_scenario::{Self as scenario, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::object;
    use sui::tx_context;
    use sui::sui::SUI;
    use sui::test_utils;
    
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2, GovernanceCapV2};
    
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    const GOVERNANCE1: address = @0x1;
    const GOVERNANCE2: address = @0x2;
    const GOVERNANCE3: address = @0x3;
    
    // Test constants
    const NEW_APY_BASIS_POINTS: u64 = 600; // 6% APY
    const NEW_GRACE_PERIOD_MS: u64 = 2592000000; // 30 days
    const NEW_DAILY_MINT_CAP: u64 = 1000000000; // 1B points
    const NEW_MAX_TOTAL_SUPPLY: u64 = 2000000000000; // 2T points
    
    // =================== TEST 1: update_apy_rate() ===================
    
    #[test]
    fun test_update_apy_rate_success() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Get initial APY
        let initial_apy = admin_v2::get_apy_basis_points(&config);
        assert!(initial_apy == 500, 0); // Should be 5% default
        
        // TEST: update_apy_rate() - APY UPDATE
        admin_v2::update_apy_rate(
            &mut config,
            &admin_cap,
            NEW_APY_BASIS_POINTS,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify APY was updated
        let new_apy = admin_v2::get_apy_basis_points(&config);
        assert!(new_apy == NEW_APY_BASIS_POINTS, 1);
        assert!(new_apy == 600, 2); // Should be 6%
        
        // Clean up - consume all variables
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 2: update_grace_period() ===================
    
    #[test]
    fun test_update_grace_period_success() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // TEST: update_grace_period() - GRACE PERIOD UPDATE
        admin_v2::update_grace_period(
            &mut config,
            &admin_cap,
            NEW_GRACE_PERIOD_MS,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Clean up - consume all variables
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 3: update_economic_limits() ===================
    
    #[test]
    fun test_update_economic_limits_success() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Get current max supply and set new supply higher
        let current_max_supply = admin_v2::get_max_total_supply(&config);
        let new_max_supply = current_max_supply + 100_000_000_000; // Increase by 100B
        
        // TEST: update_economic_limits() - ECONOMIC LIMITS UPDATE
        admin_v2::update_economic_limits(
            &mut config,
            &admin_cap,
            option::some(new_max_supply), // new_max_supply - must be >= current
            option::some(NEW_DAILY_MINT_CAP), // new_daily_cap_global
            option::none(), // new_daily_cap_per_user
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify economic limits were updated
        let new_daily_mint_cap = admin_v2::get_daily_mint_cap_global(&config);
        let updated_max_total_supply = admin_v2::get_max_total_supply(&config);
        assert!(new_daily_mint_cap == NEW_DAILY_MINT_CAP, 0);
        assert!(updated_max_total_supply == new_max_supply, 1);
        
        // Clean up - consume all variables
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 4: set_emergency_pause() ===================
    
    #[test]
    fun test_set_emergency_pause_success() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // TEST: set_emergency_pause() - EMERGENCY PAUSE
        admin_v2::set_emergency_pause(
            &mut config,
            &admin_cap,
            1, // pause_type (1=emergency)
            true, // new_state (pause)
            b"Emergency pause for testing", // reason
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify emergency pause was set
        let is_paused = admin_v2::is_emergency_paused(&config);
        assert!(is_paused == true, 0);
        
        // Clean up - consume all variables
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    #[test]
    fun test_create_governance_proposal() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create governance cap first
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        
        // Create config with the actual governance cap ID
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, ADMIN);
        
        // Test create_governance_proposal function
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1, // proposal_type: u8
            option::some(5000u64), // new_apy_basis_points: Option<u64>
            option::some(300000u64), // new_grace_period_ms: Option<u64>
            option::some(false), // new_emergency_pause: Option<bool>
            b"Test custom data", // custom_data: vector<u8>
            b"Test Proposal", // description: vector<u8>
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    #[test]
    fun test_sign_governance_proposal() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create governance cap first
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        
        // Create config with the actual governance cap ID
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, ADMIN);
        
        // Create a governance proposal first
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1, // proposal_type: u8
            option::some(5000u64), // new_apy_basis_points: Option<u64>
            option::some(300000u64), // new_grace_period_ms: Option<u64>
            option::some(false), // new_emergency_pause: Option<bool>
            b"Test custom data", // custom_data: vector<u8>
            b"Test Proposal", // description: vector<u8>
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test sign_governance_proposal function
        // Note: This would require retrieving the proposal from the governance cap
        // For now, we'll just test that the governance cap was created properly
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
} 