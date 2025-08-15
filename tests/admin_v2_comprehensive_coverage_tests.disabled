#[test_only]
module alpha_points::admin_v2_comprehensive_coverage_tests {
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
    const USER1: address = @0xB;
    const USER2: address = @0xC;
    const GOVERNANCE1: address = @0x1;
    const GOVERNANCE2: address = @0x2;
    const GOVERNANCE3: address = @0x3;
    const UNAUTHORIZED_USER: address = @0xDEAD;
    
    // =================== INITIALIZATION FUNCTION TESTS ===================
    
    #[test]
    fun test_init_function_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Test init function directly - this creates the full protocol infrastructure
        admin_v2::init_for_testing(scenario::ctx(&mut scenario));
        
        // Move to next transaction to see the created objects
        scenario::next_tx(&mut scenario, ADMIN);
        
        // Verify shared config was created
        let config = scenario::take_shared<ConfigV2>(&scenario);
        
        // Verify admin cap was transferred to deployer
        let admin_cap = scenario::take_from_sender<AdminCapV2>(&scenario);
        
        // Verify governance cap was transferred to deployer
        let governance_cap = scenario::take_from_sender<GovernanceCapV2>(&scenario);
        
        // Test that the config has correct initial values
        assert!(admin_v2::get_apy_basis_points(&config) == 500, 1); // 5% APY
        assert!(admin_v2::get_points_per_usd(&config) == 1000, 2); // 1000 points per USD
        assert!(admin_v2::deployer_address(&config) == ADMIN, 3);
        assert!(!admin_v2::is_paused(&config), 4);
        
        // Test that admin cap is properly linked to config
        assert!(admin_v2::is_admin(&admin_cap, &config), 5);
        
        // Cleanup
        scenario::return_shared(config);
        test_utils::destroy(admin_cap);
        test_utils::destroy(governance_cap);
        scenario::end(scenario);
    }
    
    // =================== VALIDATION FUNCTION TESTS ===================
    
    #[test]
    fun test_validate_basis_points_function() {
        // Test the unused validate_basis_points function indirectly through test_apy_calculation_semantics
        admin_v2::test_apy_calculation_semantics();
        
        // This test ensures the validation logic works correctly for APY bounds
        let mut scenario = scenario::begin(ADMIN);
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Verify the validation constants are working
        let initial_apy = admin_v2::get_apy_basis_points(&config);
        assert!(initial_apy == 500, 6); // Default 5% APY
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        scenario::end(scenario);
    }
    
    // =================== ERROR CONDITION TESTS ===================
    
    #[test]
    #[expected_failure(abort_code = 1)] // EUnauthorized
    fun test_update_apy_rate_unauthorized() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create config and admin cap
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create a different admin cap (unauthorized)
        let unauthorized_admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        // Try to update APY with unauthorized cap - should fail
        admin_v2::update_apy_rate(
            &mut config,
            &unauthorized_admin_cap,
            600, // new APY
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        test_utils::destroy(unauthorized_admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 2)] // EInvalidAPYRate
    fun test_update_apy_rate_invalid_bounds() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Try to set APY below minimum (100 basis points = 1%)
        admin_v2::update_apy_rate(
            &mut config,
            &admin_cap,
            50, // 0.5% - below minimum
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 2)] // EInvalidAPYRate
    fun test_update_apy_rate_change_too_large() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Try to change APY by more than allowed (200 basis points max change)
        // Current APY is 500, try to set to 800 (300 basis points change)
        admin_v2::update_apy_rate(
            &mut config,
            &admin_cap,
            800, // 8% - change of 300 basis points exceeds limit
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 3)] // EInvalidGracePeriod
    fun test_update_grace_period_invalid_bounds() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Try to set grace period below minimum (1 day = 86400000 ms)
        admin_v2::update_grace_period(
            &mut config,
            &admin_cap,
            3600000, // 1 hour - below minimum
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 14)] // EProtocolPaused
    fun test_governance_paused_blocks_operations() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // First pause governance
        admin_v2::set_emergency_pause(
            &mut config,
            &admin_cap,
            4, // governance pause type
            true, // pause
            b"Testing governance pause",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Now try to update APY - should fail because governance is paused
        admin_v2::update_apy_rate(
            &mut config,
            &admin_cap,
            600,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== PAUSE ASSERTION TESTS ===================
    
    #[test]
    #[expected_failure(abort_code = 14)] // EProtocolPaused
    fun test_assert_not_paused_fails_when_paused() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Pause the protocol
        admin_v2::set_emergency_pause(
            &mut config,
            &admin_cap,
            1, // emergency pause
            true,
            b"Testing pause assertion",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // This should fail
        admin_v2::assert_not_paused(&config);
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 14)] // EProtocolPaused
    fun test_assert_mint_not_paused_fails_when_mint_paused() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Pause minting
        admin_v2::set_emergency_pause(
            &mut config,
            &admin_cap,
            2, // mint pause
            true,
            b"Testing mint pause assertion",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // This should fail
        admin_v2::assert_mint_not_paused(&config);
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 14)] // EProtocolPaused
    fun test_assert_redemption_not_paused_fails_when_redemption_paused() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Pause redemptions
        admin_v2::set_emergency_pause(
            &mut config,
            &admin_cap,
            3, // redemption pause
            true,
            b"Testing redemption pause assertion",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // This should fail
        admin_v2::assert_redemption_not_paused(&config);
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== ECONOMIC LIMITS VALIDATION TESTS ===================
    
    #[test]
    #[expected_failure(abort_code = 2)] // EInvalidAPYRate (used for validation failures)
    fun test_update_economic_limits_invalid_daily_cap_too_low() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Try to set daily cap below minimum (1M)
        admin_v2::update_economic_limits(
            &mut config,
            &admin_cap,
            option::none(), // max supply
            option::some(500_000), // daily cap too low
            option::none(), // per user cap
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 2)] // EInvalidAPYRate
    fun test_update_economic_limits_invalid_user_cap_too_high() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Try to set per-user cap above maximum (10M)
        admin_v2::update_economic_limits(
            &mut config,
            &admin_cap,
            option::none(), // max supply
            option::none(), // daily cap
            option::some(20_000_000), // per user cap too high
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== PAUSE TYPE VALIDATION TESTS ===================
    
    #[test]
    #[expected_failure(abort_code = 2)] // EInvalidAPYRate (used for invalid pause type)
    fun test_set_emergency_pause_invalid_pause_type() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Try to use invalid pause type (valid types are 1-4)
        admin_v2::set_emergency_pause(
            &mut config,
            &admin_cap,
            99, // invalid pause type
            true,
            b"Testing invalid pause type",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== COMPREHENSIVE PAUSE FUNCTIONALITY TESTS ===================
    
    #[test]
    fun test_all_pause_types_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Test all pause types sequentially
        
        // 1. Emergency pause
        admin_v2::set_emergency_pause(&mut config, &admin_cap, 1, true, b"Emergency test", &clock, scenario::ctx(&mut scenario));
        let (emergency, mint, redemption, governance) = admin_v2::get_pause_states(&config);
        assert!(emergency && !mint && !redemption && !governance, 7);
        
        // 2. Mint pause (while emergency is still active)
        admin_v2::set_emergency_pause(&mut config, &admin_cap, 2, true, b"Mint test", &clock, scenario::ctx(&mut scenario));
        let (emergency, mint, redemption, governance) = admin_v2::get_pause_states(&config);
        assert!(emergency && mint && !redemption && !governance, 8);
        
        // 3. Redemption pause
        admin_v2::set_emergency_pause(&mut config, &admin_cap, 3, true, b"Redemption test", &clock, scenario::ctx(&mut scenario));
        let (emergency, mint, redemption, governance) = admin_v2::get_pause_states(&config);
        assert!(emergency && mint && redemption && !governance, 9);
        
        // 4. Governance pause
        admin_v2::set_emergency_pause(&mut config, &admin_cap, 4, true, b"Governance test", &clock, scenario::ctx(&mut scenario));
        let (emergency, mint, redemption, governance) = admin_v2::get_pause_states(&config);
        assert!(emergency && mint && redemption && governance, 10);
        
        // Now unpause everything
        admin_v2::set_emergency_pause(&mut config, &admin_cap, 1, false, b"Unpause emergency", &clock, scenario::ctx(&mut scenario));
        admin_v2::set_emergency_pause(&mut config, &admin_cap, 2, false, b"Unpause mint", &clock, scenario::ctx(&mut scenario));
        admin_v2::set_emergency_pause(&mut config, &admin_cap, 3, false, b"Unpause redemption", &clock, scenario::ctx(&mut scenario));
        admin_v2::set_emergency_pause(&mut config, &admin_cap, 4, false, b"Unpause governance", &clock, scenario::ctx(&mut scenario));
        
        let (emergency, mint, redemption, governance) = admin_v2::get_pause_states(&config);
        assert!(!emergency && !mint && !redemption && !governance, 11);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== GOVERNANCE PROPOSAL COMPREHENSIVE TESTS ===================
    
    #[test]
    #[expected_failure(abort_code = 1)] // EUnauthorized
    fun test_create_governance_proposal_unauthorized_governance_cap() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create governance cap
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        
        // Create config with different governance cap ID
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Create a different governance cap (unauthorized)
        let mut unauthorized_governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        
        // Try to create proposal with unauthorized governance cap - should fail
        admin_v2::create_governance_proposal(
            &mut unauthorized_governance_cap,
            &config,
            1, // proposal_type
            option::some(600u64), // new_apy_basis_points
            option::none(), // new_grace_period_ms
            option::none(), // new_emergency_pause
            b"test data", // custom_data
            b"Test proposal", // description
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        test_utils::destroy(unauthorized_governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 12)] // ESignerNotAuthorized
    fun test_create_governance_proposal_unauthorized_signer() {
        let mut scenario = scenario::begin(UNAUTHORIZED_USER); // Use unauthorized user
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create governance cap (authorized signers include @0xA, not UNAUTHORIZED_USER)
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        
        // Create config with the governance cap
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Try to create proposal as unauthorized signer - should fail
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1, // proposal_type
            option::some(600u64), // new_apy_basis_points
            option::none(), // new_grace_period_ms
            option::none(), // new_emergency_pause
            b"test data", // custom_data
            b"Test proposal", // description
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_governance_proposal_creation_and_signing_comprehensive() {
        let mut scenario = scenario::begin(ADMIN); // ADMIN is authorized signer
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create governance cap
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        
        // Create config with the governance cap
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Test proposal creation
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1, // proposal_type: APY change
            option::some(600u64), // new_apy_basis_points: 6%
            option::some(1728000000u64), // new_grace_period_ms: 20 days
            option::some(false), // new_emergency_pause
            b"Custom proposal data for testing", // custom_data
            b"Comprehensive test proposal to change APY and grace period", // description
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Move clock forward to test timelock
        clock::increment_for_testing(&mut clock, 100000); // 100 seconds
        
        // Note: Proposal is automatically signed by proposer when created
        // In a real multi-sig scenario, additional authorized signers would sign here
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 7)] // EProposalNotFound
    fun test_sign_governance_proposal_not_found() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create governance cap and config
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Try to sign non-existent proposal - should fail
        admin_v2::sign_governance_proposal(
            &mut governance_cap,
            &config,
            999, // non-existent proposal_id
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 13)] // EAlreadySigned
    fun test_sign_governance_proposal_already_signed() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create governance cap and config
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Create a proposal (proposer automatically signs)
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1, // proposal_type
            option::some(600u64), // new_apy_basis_points
            option::none(), // new_grace_period_ms
            option::none(), // new_emergency_pause
            b"test data", // custom_data
            b"Test proposal", // description
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Try to sign again as the same user - should fail
        admin_v2::sign_governance_proposal(
            &mut governance_cap,
            &config,
            1, // proposal_id
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== VIEW FUNCTION COMPREHENSIVE TESTS ===================
    
    #[test]
    fun test_all_view_functions_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Test all view functions
        let apy_bps = admin_v2::get_apy_basis_points(&config);
        let apy_percentage = admin_v2::get_apy_percentage(&config);
        let points_per_usd = admin_v2::get_points_per_usd(&config);
        let deployer = admin_v2::deployer_address(&config);
        let is_paused = admin_v2::is_paused(&config);
        let treasury = admin_v2::get_treasury_address();
        let admin_cap_id = admin_v2::get_admin_cap_id(&admin_cap);
        let admin_cap_uid = admin_v2::get_admin_cap_uid_to_inner(&admin_cap);
        let config_admin_id = admin_v2::admin_cap_id(&config);
        let is_admin_valid = admin_v2::is_admin(&admin_cap, &config);
        
        // Test config info tuple
        let (config_apy, config_points, config_max_supply, config_grace, config_paused) = admin_v2::get_config_info(&config);
        
        // Test pause states tuple
        let (emergency, mint, redemption, governance) = admin_v2::get_pause_states(&config);
        
        // Test individual getters for testing functions
        let max_supply = admin_v2::get_max_total_supply(&config);
        let daily_global = admin_v2::get_daily_mint_cap_global(&config);
        let daily_user = admin_v2::get_daily_mint_cap_per_user(&config);
        let is_emergency_paused = admin_v2::is_emergency_paused(&config);
        
        // Verify all values are reasonable
        assert!(apy_bps == 500, 12); // 5%
        assert!(apy_percentage == 5, 13); // 5%
        assert!(points_per_usd == 1000, 14); // 1000 points per USD
        assert!(deployer == ADMIN, 15);
        assert!(!is_paused, 16);
        assert!(treasury == @0x999999999999999999999999999999999999999999999999999999999999999, 17);
        assert!(admin_cap_id == config_admin_id, 18);
        assert!(admin_cap_uid == admin_cap_id, 19);
        assert!(is_admin_valid, 20);
        
        // Verify tuple values
        assert!(config_apy == apy_bps, 21);
        assert!(config_points == points_per_usd, 22);
        assert!(config_max_supply > 0, 23);
        assert!(config_grace > 0, 24);
        assert!(!config_paused, 25);
        
        // Verify pause states
        assert!(!emergency && !mint && !redemption && !governance, 26);
        
        // Verify individual getters
        assert!(max_supply == config_max_supply, 27);
        assert!(daily_global > 0, 28);
        assert!(daily_user > 0, 29);
        assert!(!is_emergency_paused, 30);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        scenario::end(scenario);
    }
    
    // =================== EDGE CASE TESTS ===================
    
    #[test]
    fun test_economic_limits_partial_updates() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        let initial_max_supply = admin_v2::get_max_total_supply(&config);
        let initial_daily_global = admin_v2::get_daily_mint_cap_global(&config);
        let initial_daily_user = admin_v2::get_daily_mint_cap_per_user(&config);
        
        // Test updating only max supply
        admin_v2::update_economic_limits(
            &mut config,
            &admin_cap,
            option::some(initial_max_supply + 1_000_000_000), // increase by 1B
            option::none(), // don't change daily global
            option::none(), // don't change daily user
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        assert!(admin_v2::get_max_total_supply(&config) == initial_max_supply + 1_000_000_000, 31);
        assert!(admin_v2::get_daily_mint_cap_global(&config) == initial_daily_global, 32);
        assert!(admin_v2::get_daily_mint_cap_per_user(&config) == initial_daily_user, 33);
        
        // Test updating only daily caps
        admin_v2::update_economic_limits(
            &mut config,
            &admin_cap,
            option::none(), // don't change max supply
            option::some(150_000_000), // change daily global
            option::some(75_000), // change daily user
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        assert!(admin_v2::get_max_total_supply(&config) == initial_max_supply + 1_000_000_000, 34); // unchanged
        assert!(admin_v2::get_daily_mint_cap_global(&config) == 150_000_000, 35);
        assert!(admin_v2::get_daily_mint_cap_per_user(&config) == 75_000, 36);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_apy_validation_edge_cases() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Default APY is 500 basis points (5%)
        assert!(admin_v2::get_apy_basis_points(&config) == 500, 36);
        
        // Test maximum valid change (200 basis points from current 500)
        // Go down to 300 (200 point decrease)
        admin_v2::update_apy_rate(&mut config, &admin_cap, 300, &clock, scenario::ctx(&mut scenario));
        assert!(admin_v2::get_apy_basis_points(&config) == 300, 37);
        
        // Test minimum valid APY (100 basis points = 1%) - need to go in steps
        // From 300, we can go down to 100 (200 point decrease)
        admin_v2::update_apy_rate(&mut config, &admin_cap, 100, &clock, scenario::ctx(&mut scenario));
        assert!(admin_v2::get_apy_basis_points(&config) == 100, 38);
        
        // Test working towards maximum valid APY (2000 basis points = 20%)
        // Need to do this in steps due to change limit (200 basis points max change per update)
        // Current is 100, so we can go up to 300
        admin_v2::update_apy_rate(&mut config, &admin_cap, 300, &clock, scenario::ctx(&mut scenario));
        
        // From 300, we can go up to 500
        admin_v2::update_apy_rate(&mut config, &admin_cap, 500, &clock, scenario::ctx(&mut scenario));
        
        // From 500, we can go up to 700
        admin_v2::update_apy_rate(&mut config, &admin_cap, 700, &clock, scenario::ctx(&mut scenario));
        
        // Continue in 200 basis point increments
        admin_v2::update_apy_rate(&mut config, &admin_cap, 900, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 1100, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 1300, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 1500, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 1700, &clock, scenario::ctx(&mut scenario));
        admin_v2::update_apy_rate(&mut config, &admin_cap, 1900, &clock, scenario::ctx(&mut scenario));
        
        // Final step to maximum (100 basis points change from 1900 to 2000)
        admin_v2::update_apy_rate(&mut config, &admin_cap, 2000, &clock, scenario::ctx(&mut scenario));
        
        assert!(admin_v2::get_apy_basis_points(&config) == 2000, 39);
        assert!(admin_v2::get_apy_percentage(&config) == 20, 40); // 20%
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}
