#[test_only]
module alpha_points::partner_v3_comprehensive_tests {
    use sui::test_scenario::{Self as scenario};
    use sui::clock;
    use sui::transfer;
    use std::string;
    use std::option;
    use sui::test_utils;
    use sui::object;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::partner_v3::{Self, PartnerCapV3, PartnerVault, PartnerRegistryV3, USDC};
    
    const ADMIN: address = @0xA;
    const PARTNER1: address = @0xB;
    const PARTNER2: address = @0xC;
    const USER1: address = @0xD;
    
    #[test]
    fun test_comprehensive_partner_vault_creation() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin infrastructure - use the correct function that returns both
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create partner registry first
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner with vault using correct function signature
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER1,
            1000000000, // collateral_amount (1000 USDC)
            50000000, // daily_quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test getter functions for coverage
        let vault_id = partner_v3::get_partner_vault_uid_to_inner(&partner_vault);
        let partner_cap_id = partner_v3::get_partner_cap_uid_to_inner(&partner_cap);
        
        // Test that IDs are not zero
        assert!(vault_id != object::id_from_address(@0x0), 28);
        assert!(partner_cap_id != object::id_from_address(@0x0), 29);
        
        // Test get_vault_info - it returns 7 values
        let (vault_name, vault_owner, vault_generation, vault_created_timestamp, vault_balance, vault_reserved, vault_is_active) = partner_v3::get_vault_info(&partner_vault);
        
        // Verify the returned values
        assert!(string::bytes(&vault_name) == b"Test Vault", 30);
        assert!(vault_owner == PARTNER1, 31);
        assert!(vault_generation == 1, 32); // DEFAULT_GENERATION_ID
        assert!(vault_balance >= 0, 33); // Balance should be non-negative
        assert!(vault_reserved == 50000000, 34); // daily_quota value
        assert!(vault_is_active == true, 35); // !vault.is_locked
        
        // Test get_partner_info_v3 (this function exists)
        let (partner_name, partner_address, partner_generation, partner_vault_id, partner_vault_owner) = partner_v3::get_partner_info_v3(&partner_cap);
        
        // Verify the returned values
        assert!(string::bytes(&partner_name) == b"Test Partner", 37);
        assert!(partner_address == PARTNER1, 38);
        assert!(partner_generation == 1, 39); // DEFAULT_GENERATION_ID
        assert!(partner_vault_owner == PARTNER1, 40);
        
        // Test get_registry_stats_v3
        let (total_partners, total_generations, total_usdc_locked, total_usdc_in_defi, total_yield_generated, total_vaults_in_defi) = partner_v3::get_registry_stats_v3(&partner_registry);
        
        // Verify the returned values
        assert!(total_partners == 1, 41);
        assert!(total_generations > 0, 42);
        assert!(total_usdc_locked > 0, 43);
        
        // Clean up - consume all objects properly
        test_utils::destroy(partner_registry);
        test_utils::destroy(partner_cap);
        test_utils::destroy(partner_vault);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_comprehensive_partner_operations() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create partner registry and partner
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner with vault
        let (partner_cap, mut partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER1,
            1000000000, // collateral_amount (1000 USDC)
            50000000, // daily_quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test add revenue to vault test function
        partner_v3::add_revenue_to_vault_test(
            &mut partner_vault,
            100000, // revenue_amount
            clock::timestamp_ms(&clock),
            scenario::ctx(&mut scenario)
        );
        
        // Test points burned callback with correct signature
        partner_v3::on_points_burned_vault(
            &mut partner_vault,
            10000, // points_burned
            &config,
            clock::timestamp_ms(&clock) // current_time_ms
        );
        
        // Test get_vault_balance function
        let vault_balance = partner_v3::get_vault_balance(&partner_vault);
        assert!(vault_balance > 0, 44);
        
        // Test get_partner_address function
        let partner_address = partner_v3::get_partner_address(&partner_cap);
        assert!(partner_address == PARTNER1, 45);
        
        // Test get_vault_partner_address function
        let vault_partner_address = partner_v3::get_vault_partner_address(&partner_vault);
        assert!(vault_partner_address == PARTNER1, 46);
        
        // Clean up - consume all objects properly
        test_utils::destroy(partner_registry);
        test_utils::destroy(partner_cap);
        test_utils::destroy(partner_vault);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}