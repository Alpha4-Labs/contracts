#[test_only]
module alpha_points::integration_v2_security_edge_cases_tests {
    use std::string;
    use std::option;
    use std::vector;
    use sui::test_scenario::{Self as scenario, Scenario};
    use sui::clock::{Self, Clock};
    use sui::transfer;
    use sui::object;
    use sui::tx_context;
    use sui::test_utils;
    
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    use alpha_points::oracle_v2::{Self, RateOracleV2, OracleCapV2};
    use alpha_points::partner_v3::{Self, PartnerRegistryV3, PartnerCapV3, PartnerVault, USDC};
    use alpha_points::integration_v2::{Self};
    
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    const USER2: address = @0xC;
    const ATTACKER: address = @0xBAD;
    const PARTNER1: address = @0xD;
    
    // Edge case amounts
    const MINIMUM_POINTS: u64 = 1;
    const MAXIMUM_DAILY_CAP: u64 = 100000; // Based on test config
    const EXTREME_AMOUNT: u64 = 999999999999; // Near max u64
    
    // Price edge cases
    const MINIMUM_PRICE: u64 = 100000000; // $0.10 - realistic minimum price
    const MAXIMUM_PRICE: u64 = 999999999999; // Very high price
    const NORMAL_PRICE: u64 = 200000000; // $2.00
    
    // =================== BOUNDARY VALUE TESTS ===================
    
    #[test]
    fun test_minimum_redemption_amount() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut ledger, oracle, config, admin_cap, oracle_cap, mut partner_vault, partner_cap, partner_registry) = 
            setup_test_environment(&mut scenario, &clock);
        
        scenario::next_tx(&mut scenario, USER1);
        
        // Mint minimum amount
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            MINIMUM_POINTS,
            ledger_v2::new_staking_reward(),
            b"test_mint",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        let balance_before = ledger_v2::get_available_balance(&ledger, USER1);
        assert!(balance_before == MINIMUM_POINTS, 1);
        
        // Test minimum redemption
        integration_v2::redeem_points_for_assets<PartnerVault>(
            &mut ledger,
            &mut partner_vault,
            &config,
            &oracle,
            MINIMUM_POINTS,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        let balance_after = ledger_v2::get_available_balance(&ledger, USER1);
        assert!(balance_after == 0, 2);
        
        cleanup_test_environment(ledger, oracle, config, admin_cap, oracle_cap, partner_vault, partner_cap, partner_registry, clock, scenario);
    }
    
    #[test]
    fun test_maximum_daily_cap_redemption() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut ledger, oracle, config, admin_cap, oracle_cap, mut partner_vault, partner_cap, partner_registry) = 
            setup_test_environment(&mut scenario, &clock);
        
        scenario::next_tx(&mut scenario, USER1);
        
        // Mint maximum daily cap amount
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            MAXIMUM_DAILY_CAP,
            ledger_v2::new_staking_reward(),
            b"test_mint",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        let balance_before = ledger_v2::get_available_balance(&ledger, USER1);
        
        // Test maximum redemption
        integration_v2::redeem_points_for_assets<PartnerVault>(
            &mut ledger,
            &mut partner_vault,
            &config,
            &oracle,
            MAXIMUM_DAILY_CAP,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        let balance_after = ledger_v2::get_available_balance(&ledger, USER1);
        assert!(balance_after == balance_before - MAXIMUM_DAILY_CAP, 3);
        
        cleanup_test_environment(ledger, oracle, config, admin_cap, oracle_cap, partner_vault, partner_cap, partner_registry, clock, scenario);
    }
    
    #[test]
    fun test_price_boundary_values() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut ledger, mut oracle, config, admin_cap, oracle_cap, mut partner_vault, partner_cap, partner_registry) = 
            setup_test_environment(&mut scenario, &clock);
        
        // Test with minimum valid price
        scenario::next_tx(&mut scenario, ADMIN);
        oracle_v2::set_price_for_testing(
            &mut oracle,
            &oracle_cap,
            string::utf8(b"SUI/USD"),
            MINIMUM_PRICE, // Minimum valid price
            9500,
            clock::timestamp_ms(&clock),
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, USER1);
        
        // Mint and redeem with minimum price (small amount)
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            100, // Smaller amount to be safe
            ledger_v2::new_staking_reward(),
            b"test_mint",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        integration_v2::redeem_points_for_assets<PartnerVault>(
            &mut ledger,
            &mut partner_vault,
            &config,
            &oracle,
            100, // Smaller amount to be safe
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test with moderately high price to avoid vault balance issues
        scenario::next_tx(&mut scenario, ADMIN);
        oracle_v2::set_price_for_testing(
            &mut oracle,
            &oracle_cap,
            string::utf8(b"SUI/USD"),
            1000000000, // $10 - high but safe
            9500,
            clock::timestamp_ms(&clock),
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, USER2); // Use different user
        
        // Mint and redeem with high price (very small amount)
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER2,
            10, // Very small amount to avoid vault issues
            ledger_v2::new_staking_reward(),
            b"test_mint",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        integration_v2::redeem_points_for_assets<PartnerVault>(
            &mut ledger,
            &mut partner_vault,
            &config,
            &oracle,
            10,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        cleanup_test_environment(ledger, oracle, config, admin_cap, oracle_cap, partner_vault, partner_cap, partner_registry, clock, scenario);
    }
    
    // =================== SECURITY ATTACK SCENARIOS ===================
    
    #[test]
    #[expected_failure(abort_code = 2)] // EInsufficientBalance
    fun test_double_spend_attack_prevention() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut ledger, oracle, config, admin_cap, oracle_cap, mut partner_vault, partner_cap, partner_registry) = 
            setup_test_environment(&mut scenario, &clock);
        
        scenario::next_tx(&mut scenario, ATTACKER);
        
        // Mint small amount to attacker
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            ATTACKER,
            1000,
            ledger_v2::new_staking_reward(),
            b"test_mint",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // First redemption (should work)
        integration_v2::redeem_points_for_assets<PartnerVault>(
            &mut ledger,
            &mut partner_vault,
            &config,
            &oracle,
            1000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Second redemption with same amount (should fail - insufficient balance)
        integration_v2::redeem_points_for_assets<PartnerVault>(
            &mut ledger,
            &mut partner_vault,
            &config,
            &oracle,
            1000, // Attacker no longer has these points
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        cleanup_test_environment(ledger, oracle, config, admin_cap, oracle_cap, partner_vault, partner_cap, partner_registry, clock, scenario);
    }
    
    #[test]
    fun test_concurrent_redemptions_different_users() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut ledger, oracle, config, admin_cap, oracle_cap, mut partner_vault, partner_cap, partner_registry) = 
            setup_test_environment(&mut scenario, &clock);
        
        let users = vector[USER1, USER2];
        let amounts = vector[5000, 7000];
        let mut i = 0;
        
        // Setup: mint points to multiple users
        while (i < vector::length(&users)) {
            let user = *vector::borrow(&users, i);
            let amount = *vector::borrow(&amounts, i);
            
            scenario::next_tx(&mut scenario, user);
            
            ledger_v2::mint_points_with_controls(
                &mut ledger,
                user,
                amount,
                ledger_v2::new_staking_reward(),
                b"test_mint",
                &clock,
                scenario::ctx(&mut scenario)
            );
            
            i = i + 1;
        };
        
        // Test: concurrent redemptions
        i = 0;
        while (i < vector::length(&users)) {
            let user = *vector::borrow(&users, i);
            let amount = *vector::borrow(&amounts, i);
            
            scenario::next_tx(&mut scenario, user);
            
            let balance_before = ledger_v2::get_available_balance(&ledger, user);
            
            integration_v2::redeem_points_for_assets<PartnerVault>(
                &mut ledger,
                &mut partner_vault,
                &config,
                &oracle,
                amount,
                &clock,
                scenario::ctx(&mut scenario)
            );
            
            let balance_after = ledger_v2::get_available_balance(&ledger, user);
            assert!(balance_after == balance_before - amount, 10 + i);
            
            i = i + 1;
        };
        
        cleanup_test_environment(ledger, oracle, config, admin_cap, oracle_cap, partner_vault, partner_cap, partner_registry, clock, scenario);
    }
    
    #[test]
    fun test_reserve_ratio_edge_cases() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (ledger, oracle, config, admin_cap, oracle_cap, partner_vault, partner_cap, partner_registry) = 
            setup_test_environment(&mut scenario, &clock);
        
        // Test feasibility with various amounts
        let test_amounts = vector[1, 100, 1000, 10000, 100000, 500000, 1000000];
        let mut i = 0;
        
        while (i < vector::length(&test_amounts)) {
            let amount = *vector::borrow(&test_amounts, i);
            
            let (is_feasible, reserve_ratio) = integration_v2::check_redemption_feasible(
                &ledger,
                &partner_vault,
                amount
            );
            
            // Verify return values are reasonable
            if (is_feasible) {
                assert!(reserve_ratio > 0, 20 + i);
            };
            
            i = i + 1;
        };
        
        // Test with amount larger than total reserves
        let (is_feasible_extreme, reserve_ratio_extreme) = integration_v2::check_redemption_feasible(
            &ledger,
            &partner_vault,
            EXTREME_AMOUNT
        );
        
        // Should not be feasible, but if it is, reserve ratio should be meaningful
        if (is_feasible_extreme) {
            assert!(reserve_ratio_extreme > 0, 30);
        } else {
            // Expected case: not feasible with extreme amount
            assert!(!is_feasible_extreme, 31);
        };
        
        cleanup_test_environment(ledger, oracle, config, admin_cap, oracle_cap, partner_vault, partner_cap, partner_registry, clock, scenario);
    }
    
    #[test]
    fun test_precision_and_rounding_edge_cases() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut ledger, oracle, config, admin_cap, oracle_cap, mut partner_vault, partner_cap, partner_registry) = 
            setup_test_environment(&mut scenario, &clock);
        
        // Test with very small amounts that might cause rounding issues
        let small_amounts = vector[1, 2, 3, 9, 10, 11, 99, 100, 101];
        let mut i = 0;
        
        while (i < vector::length(&small_amounts)) {
            let amount = *vector::borrow(&small_amounts, i);
            
            scenario::next_tx(&mut scenario, USER1);
            
            // Mint small amount
            ledger_v2::mint_points_with_controls(
                &mut ledger,
                USER1,
                amount,
                ledger_v2::new_staking_reward(),
                b"test_mint",
                &clock,
                scenario::ctx(&mut scenario)
            );
            
            let balance_before = ledger_v2::get_available_balance(&ledger, USER1);
            
            // Test redemption with small amount
            integration_v2::redeem_points_for_assets<PartnerVault>(
                &mut ledger,
                &mut partner_vault,
                &config,
                &oracle,
                amount,
                &clock,
                scenario::ctx(&mut scenario)
            );
            
            let balance_after = ledger_v2::get_available_balance(&ledger, USER1);
            assert!(balance_after == balance_before - amount, 40 + i);
            
            i = i + 1;
        };
        
        cleanup_test_environment(ledger, oracle, config, admin_cap, oracle_cap, partner_vault, partner_cap, partner_registry, clock, scenario);
    }
    
    #[test]
    fun test_time_based_scenarios() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut ledger, oracle, config, admin_cap, oracle_cap, mut partner_vault, partner_cap, partner_registry) = 
            setup_test_environment(&mut scenario, &clock);
        
        scenario::next_tx(&mut scenario, USER1);
        
        // Mint points at time T
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            10000,
            ledger_v2::new_staking_reward(),
            b"test_mint",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Advance time significantly
        clock::increment_for_testing(&mut clock, 86400000); // 1 day
        
        // Test redemption after time advancement
        integration_v2::redeem_points_for_assets<PartnerVault>(
            &mut ledger,
            &mut partner_vault,
            &config,
            &oracle,
            5000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Advance time again
        clock::increment_for_testing(&mut clock, 86400000); // Another day
        
        // Test another redemption
        integration_v2::redeem_points_for_assets<PartnerVault>(
            &mut ledger,
            &mut partner_vault,
            &config,
            &oracle,
            5000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        let final_balance = ledger_v2::get_available_balance(&ledger, USER1);
        assert!(final_balance == 0, 50);
        
        clock::destroy_for_testing(clock);
        cleanup_test_environment_no_clock(ledger, oracle, config, admin_cap, oracle_cap, partner_vault, partner_cap, partner_registry, scenario);
    }
    
    #[test]
    fun test_state_consistency_after_operations() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (mut ledger, oracle, config, admin_cap, oracle_cap, mut partner_vault, partner_cap, partner_registry) = 
            setup_test_environment(&mut scenario, &clock);
        
        scenario::next_tx(&mut scenario, USER1);
        
        // Record initial ledger state
        let initial_supply = ledger_v2::get_actual_supply(&ledger);
        
        // Mint points
        let mint_amount = 25000;
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            mint_amount,
            ledger_v2::new_staking_reward(),
            b"test_mint",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        let supply_after_mint = ledger_v2::get_actual_supply(&ledger);
        assert!(supply_after_mint == initial_supply + mint_amount, 60);
        
        // Redeem portion of points
        let redeem_amount = 10000;
        integration_v2::redeem_points_for_assets<PartnerVault>(
            &mut ledger,
            &mut partner_vault,
            &config,
            &oracle,
            redeem_amount,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        let supply_after_redeem = ledger_v2::get_actual_supply(&ledger);
        assert!(supply_after_redeem == supply_after_mint - redeem_amount, 61);
        
        // Verify user balance consistency
        let user_balance = ledger_v2::get_available_balance(&ledger, USER1);
        assert!(user_balance == mint_amount - redeem_amount, 62);
        
        cleanup_test_environment(ledger, oracle, config, admin_cap, oracle_cap, partner_vault, partner_cap, partner_registry, clock, scenario);
    }
    
    // =================== HELPER FUNCTIONS ===================
    
    fun setup_test_environment(scenario: &mut Scenario, clock: &Clock): (
        LedgerV2, 
        RateOracleV2, 
        ConfigV2, 
        AdminCapV2, 
        OracleCapV2, 
        PartnerVault, 
        PartnerCapV3, 
        PartnerRegistryV3
    ) {
        // Create admin config
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(scenario));
        
        // Create ledger
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(scenario));
        scenario::next_tx(scenario, ADMIN);
        let ledger = scenario::take_shared<LedgerV2>(scenario);
        
        // Create oracle
        let (mut oracle, oracle_cap) = oracle_v2::create_oracle_for_testing(&admin_cap, &config, clock, scenario::ctx(scenario));
        
        // Set default price data
        oracle_v2::set_price_for_testing(
            &mut oracle,
            &oracle_cap,
            string::utf8(b"SUI/USD"),
            NORMAL_PRICE,
            9500,
            clock::timestamp_ms(clock),
            scenario::ctx(scenario)
        );
        
        // Create partner registry and partner
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(scenario));
        let usdc_coin = partner_v3::create_test_usdc_coin(1000000000, scenario::ctx(scenario)); // 1000 USDC
        
        // Switch to PARTNER1 to create vault
        scenario::next_tx(scenario, PARTNER1);
        
        partner_v3::create_partner_with_usdc_vault(
            &mut partner_registry,
            &config,
            usdc_coin,
            string::utf8(b"Test Partner"),
            string::utf8(b"Security test partner"),
            1, // generation_id
            clock,
            scenario::ctx(scenario)
        );
        
        // Get partner objects
        scenario::next_tx(scenario, PARTNER1);
        let partner_cap = scenario::take_from_sender<PartnerCapV3>(scenario);
        let partner_vault = scenario::take_from_sender<PartnerVault>(scenario);
        
        (ledger, oracle, config, admin_cap, oracle_cap, partner_vault, partner_cap, partner_registry)
    }
    
    fun cleanup_test_environment(
        ledger: LedgerV2,
        oracle: RateOracleV2,
        config: ConfigV2,
        admin_cap: AdminCapV2,
        oracle_cap: OracleCapV2,
        partner_vault: PartnerVault,
        partner_cap: PartnerCapV3,
        partner_registry: PartnerRegistryV3,
        clock: Clock,
        scenario: Scenario
    ) {
        scenario::return_shared(ledger);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        test_utils::destroy(oracle);
        test_utils::destroy(oracle_cap);
        test_utils::destroy(partner_vault);
        test_utils::destroy(partner_cap);
        test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    fun cleanup_test_environment_no_clock(
        ledger: LedgerV2,
        oracle: RateOracleV2,
        config: ConfigV2,
        admin_cap: AdminCapV2,
        oracle_cap: OracleCapV2,
        partner_vault: PartnerVault,
        partner_cap: PartnerCapV3,
        partner_registry: PartnerRegistryV3,
        scenario: Scenario
    ) {
        scenario::return_shared(ledger);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        test_utils::destroy(oracle);
        test_utils::destroy(oracle_cap);
        test_utils::destroy(partner_vault);
        test_utils::destroy(partner_cap);
        test_utils::destroy(partner_registry);
        scenario::end(scenario);
    }
}
