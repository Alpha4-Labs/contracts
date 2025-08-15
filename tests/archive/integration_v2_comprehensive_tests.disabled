#[test_only] 
module alpha_points::integration_v2_comprehensive_tests {
    use std::string;
    use std::vector;
    use sui::test_scenario::{Self as scenario, Scenario};
    use sui::clock::{Self, Clock};
    use sui::object;
    use sui::test_utils;
    
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    use alpha_points::oracle_v2::{Self, RateOracleV2, OracleCapV2};
    use alpha_points::partner_v3::{Self, PartnerRegistryV3, PartnerCapV3, PartnerVault, USDC};
    use alpha_points::integration_v2::{Self};
    
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    const USER2: address = @0xC;
    const USER3: address = @0xD;
    const PARTNER1: address = @0xE;
    
    // =================== COMPREHENSIVE INTEGRATION TESTS ===================
    
    #[test]
    fun test_integration_v2_helper_functions_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup basic environment
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create ledger
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Create partner registry and vault
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let usdc_coin = partner_v3::create_test_usdc_coin(1000000000, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER1);
        partner_v3::create_partner_with_usdc_vault(
            &mut partner_registry,
            &config,
            usdc_coin,
            string::utf8(b"Test Partner"),
            string::utf8(b"Comprehensive test partner"),
            1,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let partner_cap = scenario::take_from_sender<PartnerCapV3>(&scenario);
        let partner_vault = scenario::take_from_sender<PartnerVault>(&scenario);
        
        // Test check_redemption_feasible with various scenarios
        let test_amounts = vector[0, 1, 1000, 10000, 100000, 1000000];
        let mut i = 0;
        
        while (i < vector::length(&test_amounts)) {
            let amount = *vector::borrow(&test_amounts, i);
            
            let (is_feasible, reserve_ratio) = integration_v2::check_redemption_feasible(
                &ledger,
                &partner_vault,
                amount
            );
            
            // All reasonable amounts should be feasible in our test setup
            if (amount <= 500000) {
                assert!(is_feasible, 100 + i);
                assert!(reserve_ratio > 0, 110 + i);
            };
            
            i = i + 1;
        };
        
        // Test with circulating supply changes
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            50000,
            ledger_v2::new_staking_reward(),
            b"test_mint_for_supply_test",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test feasibility after supply increase
        let (is_feasible_after_mint, reserve_ratio_after_mint) = integration_v2::check_redemption_feasible(
            &ledger,
            &partner_vault,
            25000
        );
        
        // Should still be feasible but with different ratio
        assert!(is_feasible_after_mint, 120);
        assert!(reserve_ratio_after_mint > 0, 121);
        
        // Cleanup
        scenario::return_shared(ledger);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        test_utils::destroy(partner_cap);
        test_utils::destroy(partner_vault);
        test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_integration_v2_reserve_calculations_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup environment with different supply levels
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Create partner vault
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let usdc_coin = partner_v3::create_test_usdc_coin(2000000000, scenario::ctx(&mut scenario)); // 2000 USDC
        
        scenario::next_tx(&mut scenario, PARTNER1);
        partner_v3::create_partner_with_usdc_vault(
            &mut partner_registry,
            &config,
            usdc_coin,
            string::utf8(b"Reserve Test Partner"),
            string::utf8(b"Partner for reserve testing"),
            1,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let partner_cap = scenario::take_from_sender<PartnerCapV3>(&scenario);
        let partner_vault = scenario::take_from_sender<PartnerVault>(&scenario);
        
        // Test reserve calculations with different supply levels (within daily cap)
        let supply_levels = vector[0, 10000, 25000, 50000, 75000];
        let users = vector[USER1, USER2, USER3, USER1, USER2]; // Use different users to avoid daily cap
        let mut i = 0;
        
        while (i < vector::length(&supply_levels)) {
            let supply_level = *vector::borrow(&supply_levels, i);
            let user = *vector::borrow(&users, i);
            
            if (supply_level > 0) { // All levels are now within daily cap
                // Mint points to reach target supply level
                ledger_v2::mint_points_with_controls(
                    &mut ledger,
                    user,
                    supply_level,
                    ledger_v2::new_staking_reward(),
                    b"supply_test",
                    &clock,
                    scenario::ctx(&mut scenario)
                );
            };
            
            // Test redemption feasibility at this supply level
            let redemption_amounts = vector[1000, 5000, 10000];
            let mut j = 0;
            
            while (j < vector::length(&redemption_amounts)) {
                let redemption_amount = *vector::borrow(&redemption_amounts, j);
                
                let (is_feasible, reserve_ratio) = integration_v2::check_redemption_feasible(
                    &ledger,
                    &partner_vault,
                    redemption_amount
                );
                
                // Document the relationship between supply and feasibility
                if (supply_level == 0) {
                    // With zero supply, most redemptions should be feasible
                    assert!(is_feasible, 200 + (i * 10) + j);
                };
                
                // Reserve ratio should always be meaningful when feasible
                if (is_feasible) {
                    assert!(reserve_ratio > 0, 300 + (i * 10) + j);
                };
                
                j = j + 1;
            };
            
            i = i + 1;
        };
        
        // Cleanup
        scenario::return_shared(ledger);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        test_utils::destroy(partner_cap);
        test_utils::destroy(partner_vault);
        test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_integration_v2_all_public_functions() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // This test ensures we cover all public functions in integration_v2
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        let (mut oracle, oracle_cap) = oracle_v2::create_oracle_for_testing(&admin_cap, &config, &clock, scenario::ctx(&mut scenario));
        oracle_v2::set_price_for_testing(
            &mut oracle,
            &oracle_cap,
            string::utf8(b"SUI/USD"),
            200000000, // $2.00
            9500,
            clock::timestamp_ms(&clock),
            scenario::ctx(&mut scenario)
        );
        
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let usdc_coin = partner_v3::create_test_usdc_coin(1000000000, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER1);
        partner_v3::create_partner_with_usdc_vault(
            &mut partner_registry,
            &config,
            usdc_coin,
            string::utf8(b"All Functions Test Partner"),
            string::utf8(b"Partner for testing all functions"),
            1,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let partner_cap = scenario::take_from_sender<PartnerCapV3>(&scenario);
        let mut partner_vault = scenario::take_from_sender<PartnerVault>(&scenario);
        
        // Test 1: check_redemption_feasible (public function)
        let (is_feasible, reserve_ratio) = integration_v2::check_redemption_feasible(
            &ledger,
            &partner_vault,
            10000
        );
        assert!(is_feasible, 400);
        assert!(reserve_ratio > 0, 401);
        
        // Test 2: redeem_points_for_assets (entry function)
        scenario::next_tx(&mut scenario, USER1);
        
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            25000,
            ledger_v2::new_staking_reward(),
            b"test_mint_all_functions",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        let balance_before = ledger_v2::get_available_balance(&ledger, USER1);
        
        integration_v2::redeem_points_for_assets<PartnerVault>(
            &mut ledger,
            &mut partner_vault,
            &config,
            &oracle,
            15000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        let balance_after = ledger_v2::get_available_balance(&ledger, USER1);
        assert!(balance_after == balance_before - 15000, 402);
        
        // Test 3: Multiple redemptions to test state consistency
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
        assert!(final_balance == balance_before - 20000, 403);
        
        // Cleanup
        scenario::return_shared(ledger);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        test_utils::destroy(oracle);
        test_utils::destroy(oracle_cap);
        test_utils::destroy(partner_cap);
        test_utils::destroy(partner_vault);
        test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}