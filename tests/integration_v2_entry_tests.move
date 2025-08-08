#[test_only]
module alpha_points::integration_v2_entry_tests {
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
    
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    use alpha_points::oracle_v2::{Self, RateOracleV2, OracleCapV2};
    use alpha_points::partner_v3::{Self, PartnerRegistryV3, PartnerCapV3, PartnerVault, USDC};
    use alpha_points::integration_v2::{Self};
    
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    const PARTNER1: address = @0xC;
    const POINTS_AMOUNT: u64 = 50000; // 50k points (within daily cap)
    
    #[test]
    fun test_redeem_points_for_assets() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create ledger
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Mint points to USER1 first so they have balance to redeem
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            POINTS_AMOUNT, // Mint within daily cap
            ledger_v2::new_staking_reward(),
            b"test_mint_for_redemption",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Create oracle
        let (mut oracle, oracle_cap) = oracle_v2::create_oracle_for_testing(&admin_cap, &config, &clock, scenario::ctx(&mut scenario));
        
        // Set price data directly for testing
        oracle_v2::set_price_for_testing(
            &mut oracle,
            &oracle_cap,
            string::utf8(b"SUI/USD"),
            200000000, // $2.00 with 8 decimals
            9500, // confidence
            clock::timestamp_ms(&clock),
            scenario::ctx(&mut scenario)
        );
        oracle_v2::set_price_for_testing(
            &mut oracle,
            &oracle_cap,
            string::utf8(b"USDC/USD"),
            100000000, // $1.00 with 8 decimals
            9500, // confidence
            clock::timestamp_ms(&clock),
            scenario::ctx(&mut scenario)
        );
        
        // Verify that the oracle has valid price data
        let (price, _, _, _, _) = oracle_v2::get_price_data(&oracle, string::utf8(b"SUI/USD"));
        assert!(price > 0, 0); // Ensure we have valid price data
        
        // Create partner registry and partner
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let usdc_coin = partner_v3::create_test_usdc_coin(1000000000, scenario::ctx(&mut scenario)); // 1000 USDC
        
        // Switch to PARTNER1 before creating the vault
        scenario::next_tx(&mut scenario, PARTNER1);
        
        partner_v3::create_partner_with_usdc_vault(
            &mut partner_registry,
            &config,
            usdc_coin,
            string::utf8(b"Test Partner"),
            string::utf8(b"Test partner description"),
            1, // generation_id
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Get the partner objects
        scenario::next_tx(&mut scenario, PARTNER1);
        let partner_cap = scenario::take_from_sender<PartnerCapV3>(&scenario);
        let mut partner_vault = scenario::take_from_sender<PartnerVault>(&scenario);
        
        // Switch to USER1 for redemption
        scenario::next_tx(&mut scenario, USER1);
        
        // Test redeem_points_for_assets function
        integration_v2::redeem_points_for_assets<PartnerVault>(
            &mut ledger,
            &mut partner_vault,
            &config,
            &oracle,
            POINTS_AMOUNT,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        scenario::return_shared(ledger);
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        test_utils::destroy(oracle);
        test_utils::destroy(oracle_cap);
        test_utils::destroy(partner_cap);
        test_utils::destroy(partner_vault);
        test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    

} 