#[test_only]
module alpha_points::perk_manager_v2_comprehensive_tests {
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::vector;
    use sui::test_scenario::{Self as scenario, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::object;
    use sui::tx_context;
    
    use alpha_points::perk_manager_v2::{Self, PerkMarketplaceV2, PerkMarketplaceCapV2};
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    use alpha_points::oracle_v2::{Self, RateOracleV2, OracleCapV2};
    use alpha_points::partner_v3::{Self, PartnerCapV3, PartnerVault, PartnerRegistryV3};

    const ADMIN: address = @0xA;
    const PARTNER: address = @0xB;
    const USER1: address = @0xC;
    const USER2: address = @0xD;

    // =================== MARKETPLACE CREATION TESTS ===================

    #[test]
    fun test_create_perk_marketplace_v2() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin cap and config (returns tuple)
        let (config, admin_cap_from_config) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        
        // Test marketplace creation - use the admin_cap that comes with the config
        perk_manager_v2::create_perk_marketplace_v2(
            &config,
            &admin_cap_from_config,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap_from_config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    #[test]
    fun test_create_marketplace_for_testing() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Create admin cap and config (returns tuple)
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        let (config, _admin_cap_from_config) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        
        // Test marketplace creation for testing
        let (marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        
        // Verify marketplace stats
        let (total_perks, total_claims, total_points, total_revenue, active_perks) = 
            perk_manager_v2::get_marketplace_stats(&marketplace);
        assert!(total_perks == 0, 1);
        assert!(total_claims == 0, 2);
        assert!(total_points == 0, 3);
        assert!(total_revenue == 0, 4);
        assert!(active_perks == 0, 5);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(_admin_cap_from_config);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        scenario::end(scenario);
    }

    // =================== PERK CREATION TESTS ===================

    #[test]
    fun test_create_perk_v2() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup dependencies
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        let (config, _admin_cap_from_config) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (mut marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER);
        
        // Create partner registry first
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner cap and vault using the correct function
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER,
            10000000, // 10 USDC collateral
            1000000,  // 1 USDC daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Create perk
        let perk_name = string::utf8(b"Test Gaming Perk");
        let perk_description = string::utf8(b"A test perk for gaming rewards");
        let perk_type = string::utf8(b"digital_good");
        let category = string::utf8(b"gaming");
        let tags = vector[string::utf8(b"gaming"), string::utf8(b"rewards")];
        
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            perk_name,
            perk_description,
            perk_type,
            category,
            tags,
            1000000, // $1.00 USDC (6 decimals)
            6000, // 60% partner share
            option::some(1000u64), // max_total_claims
            option::some(10u64), // max_claims_per_user
            option::none(), // no expiration
            true, // is_consumable
            option::some(5u64), // max_uses_per_claim
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify marketplace stats updated
        let (total_perks, _, _, _, active_perks) = perk_manager_v2::get_marketplace_stats(&marketplace);
        assert!(total_perks == 1, 10);
        assert!(active_perks == 1, 11);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(_admin_cap_from_config);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    // =================== VIEW FUNCTIONS TESTS ===================

    #[test]
    fun test_get_marketplace_stats() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Setup
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        let (config, _admin_cap_from_config) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        
        // Test marketplace stats
        let (total_perks, total_claims, total_points, total_revenue, active_perks) = 
            perk_manager_v2::get_marketplace_stats(&marketplace);
        
        assert!(total_perks == 0, 30);
        assert!(total_claims == 0, 31);
        assert!(total_points == 0, 32);
        assert!(total_revenue == 0, 33);
        assert!(active_perks == 0, 34);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(_admin_cap_from_config);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        scenario::end(scenario);
    }

    #[test]
    fun test_get_perks_by_category() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Setup
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        let (config, _admin_cap_from_config) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        
        // Test getting perks by category (empty marketplace)
        let gaming_perks = perk_manager_v2::get_perks_by_category(&marketplace, string::utf8(b"gaming"));
        let rewards_perks = perk_manager_v2::get_perks_by_category(&marketplace, string::utf8(b"rewards"));
        
        assert!(vector::length(&gaming_perks) == 0, 70);
        assert!(vector::length(&rewards_perks) == 0, 71);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(_admin_cap_from_config);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        scenario::end(scenario);
    }

    #[test]
    fun test_get_perks_by_partner() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Setup
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        let (config, _admin_cap_from_config) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create partner
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER,
            10000000, // 10 USDC collateral
            1000000,  // 1 USDC daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test getting perks by partner (empty)
        let partner_cap_id = partner_v3::get_partner_cap_uid_to_inner(&partner_cap);
        let partner_perks = perk_manager_v2::get_perks_by_partner(&marketplace, partner_cap_id);
        
        assert!(vector::length(&partner_perks) == 0, 80);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(_admin_cap_from_config);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    // =================== ADMIN FUNCTIONS TESTS ===================

    #[test]
    fun test_emergency_pause_and_resume_marketplace() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        let (config, _admin_cap_from_config) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (mut marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        
        // Test emergency pause
        perk_manager_v2::emergency_pause_marketplace(
            &mut marketplace,
            &marketplace_cap,
            string::utf8(b"Testing emergency pause"),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test resume operations
        perk_manager_v2::resume_marketplace_operations(
            &mut marketplace,
            &marketplace_cap,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(_admin_cap_from_config);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    #[test]
    fun test_create_test_marketplace_cap() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Create test marketplace cap
        let marketplace_id = object::id_from_address(@0x123);
        let marketplace_cap = perk_manager_v2::create_test_marketplace_cap(marketplace_id, scenario::ctx(&mut scenario));
        
        // Verify it was created successfully
        // (The fact that this doesn't abort means it worked)
        
        // Cleanup
        sui::test_utils::destroy(marketplace_cap);
        scenario::end(scenario);
    }
}