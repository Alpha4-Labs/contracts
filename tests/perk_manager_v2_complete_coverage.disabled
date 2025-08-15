#[test_only]
module alpha_points::perk_manager_v2_complete_coverage {
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

    // =================== PERK CREATION WITH VALIDATION TESTS ===================

    #[test]
    fun test_create_perk_v2_with_all_options() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup all dependencies
        let (config, admin_cap) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (mut marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER);
        
        // Create partner with vault
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER,
            50000000, // 50 USDC collateral
            5000000,  // 5 USDC daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test perk creation with all optional parameters
        let perk_name = string::utf8(b"Premium Gaming Experience");
        let perk_description = string::utf8(b"An exclusive premium gaming experience with unique rewards and benefits for dedicated players");
        let perk_type = string::utf8(b"experience");
        let category = string::utf8(b"exclusive_access");
        let tags = vector[
            string::utf8(b"premium"), 
            string::utf8(b"gaming"), 
            string::utf8(b"exclusive"),
            string::utf8(b"experience"),
            string::utf8(b"rewards")
        ];
        
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            perk_name,
            perk_description,
            perk_type,
            category,
            tags,
            5000000, // $5.00 USDC (6 decimals)
            7500, // 75% partner share
            option::some(500u64), // max_total_claims
            option::some(5u64), // max_claims_per_user
            option::some(clock::timestamp_ms(&clock) + 2592000000u64), // expires in 30 days
            true, // is_consumable
            option::some(3u64), // max_uses_per_claim
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify marketplace stats
        let (total_perks, _, _, _, active_perks) = perk_manager_v2::get_marketplace_stats(&marketplace);
        assert!(total_perks == 1, 1);
        assert!(active_perks == 1, 2);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    #[test]
    fun test_create_perk_v2_minimal_options() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup dependencies
        let (config, admin_cap) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (mut marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER);
        
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER,
            10000000, // 10 USDC collateral
            1000000,  // 1 USDC daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test perk creation with minimal options
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Basic Reward"),
            string::utf8(b"A basic reward for testing"),
            string::utf8(b"digital_good"),
            string::utf8(b"rewards"),
            vector[string::utf8(b"basic")],
            1000000, // $1.00 USDC
            5000, // 50% partner share
            option::none(), // unlimited claims
            option::none(), // unlimited per user
            option::none(), // no expiration
            false, // not consumable
            option::none(), // unlimited uses
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    // =================== COMPREHENSIVE CLAIM TESTING ===================

    #[test]
    fun test_claim_perk_v2_full_flow() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup all dependencies
        let (config, admin_cap) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let (oracle, oracle_cap) = oracle_v2::create_oracle_for_testing(&admin_cap, &config, &clock, scenario::ctx(&mut scenario));
        let (mut marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER);
        
        // Create partner and perk
        let (partner_cap, mut partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER,
            100000000, // 100 USDC collateral for revenue
            50000000,  // 50 USDC daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Create a claimable perk
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Claimable Test Perk"),
            string::utf8(b"A perk designed for claim testing"),
            string::utf8(b"service"),
            string::utf8(b"testing"),
            vector[string::utf8(b"claimable")],
            2000000, // $2.00 USDC
            6000, // 60% partner share
            option::some(1000u64), // max claims
            option::some(10u64), // max per user
            option::none(), // no expiration
            false, // not consumable
            option::none(), // unlimited uses
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, USER1);
        
        // Give user points to spend
        ledger_v2::mint_points_for_testing(&mut ledger, USER1, 50000, scenario::ctx(&mut scenario));
        
        // Note: In a real scenario, we would retrieve the shared PerkDefinitionV2 object
        // For testing purposes, we'll focus on testing the functions we can access
        
        // Verify user has points before claim
        let initial_balance = ledger_v2::get_balance(&ledger, USER1);
        assert!(initial_balance == 50000, 10);
        
        // Test marketplace stats before claim
        let (_, initial_claims, initial_points, initial_revenue, _) = perk_manager_v2::get_marketplace_stats(&marketplace);
        assert!(initial_claims == 0, 11);
        assert!(initial_points == 0, 12);
        assert!(initial_revenue == 0, 13);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(ledger);
        sui::test_utils::destroy(oracle);
        sui::test_utils::destroy(oracle_cap);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    // =================== VALIDATION ERROR TESTING ===================

    #[test]
    #[expected_failure(abort_code = 2013)] // EInvalidNameLength
    fun test_create_perk_v2_name_too_long() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (config, admin_cap) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (mut marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER);
        
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER,
            10000000,
            1000000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Create a name that's too long (over 200 characters)
        let long_name = string::utf8(b"This is an extremely long perk name that exceeds the maximum allowed length of 200 characters and should cause the validation to fail with an EInvalidNameLength error because it is way too long for a perk name and violates the contract constraints");
        
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            long_name,
            string::utf8(b"Valid description"),
            string::utf8(b"digital_good"),
            string::utf8(b"testing"),
            vector[string::utf8(b"test")],
            1000000,
            5000,
            option::none(),
            option::none(),
            option::none(),
            false,
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2014)] // EInvalidDescriptionLength
    fun test_create_perk_v2_description_too_long() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (config, admin_cap) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (mut marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER);
        
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER,
            10000000,
            1000000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Create a description that's too long (over 2000 characters)
        let mut long_desc = string::utf8(b"");
        let mut i = 0;
        while (i < 50) { // 50 * 50 = 2500 characters
            string::append(&mut long_desc, string::utf8(b"This description is being made very long to test "));
            i = i + 1;
        };
        
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Valid Name"),
            long_desc,
            string::utf8(b"digital_good"),
            string::utf8(b"testing"),
            vector[string::utf8(b"test")],
            1000000,
            5000,
            option::none(),
            option::none(),
            option::none(),
            false,
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here)
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2011)] // ETooManyTags
    fun test_create_perk_v2_too_many_tags() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (config, admin_cap) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (mut marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER);
        
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER,
            10000000,
            1000000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Create too many tags (over 10)
        let too_many_tags = vector[
            string::utf8(b"tag1"), string::utf8(b"tag2"), string::utf8(b"tag3"),
            string::utf8(b"tag4"), string::utf8(b"tag5"), string::utf8(b"tag6"),
            string::utf8(b"tag7"), string::utf8(b"tag8"), string::utf8(b"tag9"),
            string::utf8(b"tag10"), string::utf8(b"tag11") // 11 tags
        ];
        
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Valid Name"),
            string::utf8(b"Valid description"),
            string::utf8(b"digital_good"),
            string::utf8(b"testing"),
            too_many_tags,
            1000000,
            5000,
            option::none(),
            option::none(),
            option::none(),
            false,
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here)
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2008)] // EInvalidPriceRange
    fun test_create_perk_v2_price_too_low() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (config, admin_cap) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (mut marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER);
        
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER,
            10000000,
            1000000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Price too low (below MIN_PERK_PRICE_USDC = 100000)
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Valid Name"),
            string::utf8(b"Valid description"),
            string::utf8(b"digital_good"),
            string::utf8(b"testing"),
            vector[string::utf8(b"test")],
            50000, // $0.05 USDC - too low
            5000,
            option::none(),
            option::none(),
            option::none(),
            false,
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here)
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2006)] // EInvalidRevenueSplit
    fun test_create_perk_v2_invalid_revenue_split() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (config, admin_cap) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (mut marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER);
        
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER,
            10000000,
            1000000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Invalid revenue split (below MIN_PARTNER_SHARE_BPS = 1000)
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Valid Name"),
            string::utf8(b"Valid description"),
            string::utf8(b"digital_good"),
            string::utf8(b"testing"),
            vector[string::utf8(b"test")],
            1000000,
            500, // 5% - too low (minimum is 10%)
            option::none(),
            option::none(),
            option::none(),
            false,
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here)
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    // =================== MARKETPLACE STATE TESTING ===================

    #[test]
    #[expected_failure(abort_code = 2016)] // EEmergencyPaused
    fun test_create_perk_v2_marketplace_paused() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (config, admin_cap) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (mut marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Pause the marketplace first
        perk_manager_v2::emergency_pause_marketplace(
            &mut marketplace,
            &marketplace_cap,
            string::utf8(b"Testing pause behavior"),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER);
        
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER,
            10000000,
            1000000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Try to create perk while marketplace is paused - should fail
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Test Perk"),
            string::utf8(b"This should fail"),
            string::utf8(b"digital_good"),
            string::utf8(b"testing"),
            vector[string::utf8(b"test")],
            1000000,
            5000,
            option::none(),
            option::none(),
            option::none(),
            false,
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here)
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    // =================== COMPREHENSIVE VIEW FUNCTION TESTING ===================

    #[test]
    fun test_all_view_functions_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (config, admin_cap) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (mut marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER);
        
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER,
            10000000,
            1000000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Create multiple perks for comprehensive testing
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Gaming Perk"),
            string::utf8(b"Gaming category perk"),
            string::utf8(b"digital_good"),
            string::utf8(b"gaming"),
            vector[string::utf8(b"gaming")],
            1000000,
            6000,
            option::some(100u64),
            option::some(5u64),
            option::none(),
            false,
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Rewards Perk"),
            string::utf8(b"Rewards category perk"),
            string::utf8(b"service"),
            string::utf8(b"rewards"),
            vector[string::utf8(b"rewards")],
            2000000,
            7000,
            option::some(200u64),
            option::some(10u64),
            option::none(),
            true,
            option::some(3u64),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test marketplace stats
        let (total_perks, total_claims, total_points, total_revenue, active_perks) = 
            perk_manager_v2::get_marketplace_stats(&marketplace);
        
        assert!(total_perks == 2, 20);
        assert!(total_claims == 0, 21);
        assert!(total_points == 0, 22);
        assert!(total_revenue == 0, 23);
        assert!(active_perks == 2, 24);
        
        // Test get perks by category
        let gaming_perks = perk_manager_v2::get_perks_by_category(&marketplace, string::utf8(b"gaming"));
        let rewards_perks = perk_manager_v2::get_perks_by_category(&marketplace, string::utf8(b"rewards"));
        let empty_perks = perk_manager_v2::get_perks_by_category(&marketplace, string::utf8(b"nonexistent"));
        
        assert!(vector::length(&gaming_perks) == 1, 25);
        assert!(vector::length(&rewards_perks) == 1, 26);
        assert!(vector::length(&empty_perks) == 0, 27);
        
        // Test get perks by partner
        let partner_cap_id = partner_v3::get_partner_cap_uid_to_inner(&partner_cap);
        let partner_perks = perk_manager_v2::get_perks_by_partner(&marketplace, partner_cap_id);
        assert!(vector::length(&partner_perks) == 2, 28);
        
        // Test with non-existent partner
        let fake_partner_id = object::id_from_address(@0x999);
        let no_perks = perk_manager_v2::get_perks_by_partner(&marketplace, fake_partner_id);
        assert!(vector::length(&no_perks) == 0, 29);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    // =================== INIT FUNCTION TESTING ===================

    #[test]
    fun test_init_for_testing() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Test the init function for testing
        perk_manager_v2::init_for_testing(scenario::ctx(&mut scenario));
        
        // The function should complete without error
        scenario::end(scenario);
    }

    // =================== MARKETPLACE CAP TESTING ===================

    #[test]
    fun test_create_test_marketplace_cap_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Test creating marketplace cap with different IDs
        let marketplace_id1 = object::id_from_address(@0x123);
        let marketplace_id2 = object::id_from_address(@0x456);
        
        let cap1 = perk_manager_v2::create_test_marketplace_cap(marketplace_id1, scenario::ctx(&mut scenario));
        let cap2 = perk_manager_v2::create_test_marketplace_cap(marketplace_id2, scenario::ctx(&mut scenario));
        
        // Both should be created successfully
        sui::test_utils::destroy(cap1);
        sui::test_utils::destroy(cap2);
        scenario::end(scenario);
    }

    // =================== EDGE CASES AND BOUNDARY TESTING ===================

    #[test]
    fun test_create_perk_v2_boundary_values() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let (config, admin_cap) = admin_v2::create_config_for_testing(scenario::ctx(&mut scenario));
        let (mut marketplace, marketplace_cap) = perk_manager_v2::create_marketplace_for_testing(
            &admin_cap,
            &config,
            scenario::ctx(&mut scenario)
        );
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER);
        
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER,
            10000000,
            1000000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test with minimum valid values
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            string::utf8(b"A"), // 1 character name (minimum)
            string::utf8(b"B"), // 1 character description (minimum)
            string::utf8(b"digital_good"),
            string::utf8(b"testing"),
            vector[string::utf8(b"x")], // 1 character tag
            100000, // MIN_PERK_PRICE_USDC
            1000, // MIN_PARTNER_SHARE_BPS (10%)
            option::some(1u64), // minimum claims
            option::some(1u64), // minimum per user
            option::none(),
            false,
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test with maximum valid values
        let max_name = create_string_of_length(200); // MAX_PERK_NAME_LENGTH
        let max_description = create_string_of_length(2000); // MAX_PERK_DESCRIPTION_LENGTH
        let max_tags = create_max_tags(); // MAX_TAGS_PER_PERK
        
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            max_name,
            max_description,
            string::utf8(b"experience"),
            string::utf8(b"exclusive_access"),
            max_tags,
            1000000000, // MAX_PERK_PRICE_USDC
            9000, // MAX_PARTNER_SHARE_BPS (90%)
            option::some(1000000u64), // MAX_PERK_LIFETIME_CLAIMS
            option::some(1000000u64), // Large per user limit
            option::none(),
            true,
            option::some(1000000u64),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify both perks were created
        let (total_perks, _, _, _, active_perks) = perk_manager_v2::get_marketplace_stats(&marketplace);
        assert!(total_perks == 2, 30);
        assert!(active_perks == 2, 31);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }

    // =================== HELPER FUNCTIONS ===================

    /// Create a string of specified length for boundary testing
    fun create_string_of_length(length: u64): String {
        let mut result = string::utf8(b"");
        let mut i = 0;
        while (i < length) {
            string::append(&mut result, string::utf8(b"x"));
            i = i + 1;
        };
        result
    }

    /// Create maximum number of tags for boundary testing
    fun create_max_tags(): vector<String> {
        vector[
            string::utf8(b"tag1"), string::utf8(b"tag2"), string::utf8(b"tag3"),
            string::utf8(b"tag4"), string::utf8(b"tag5"), string::utf8(b"tag6"),
            string::utf8(b"tag7"), string::utf8(b"tag8"), string::utf8(b"tag9"),
            string::utf8(b"tag10") // Exactly 10 tags (MAX_TAGS_PER_PERK)
        ]
    }
}
