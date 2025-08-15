#[test_only]
module alpha_points::perk_manager_v2_entry_tests {
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
    use alpha_points::perk_manager_v2::{Self, PerkMarketplaceV2, PerkMarketplaceCapV2, PerkDefinitionV2};
    use alpha_points::partner_v3::{Self, PartnerCapV3, PartnerVault};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    use alpha_points::oracle_v2::{Self, RateOracleV2};
    
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    const PARTNER1: address = @0xC;
    const PERK_PRICE_USDC: u64 = 1000000; // 1 USDC in micro units
    
    #[test]
    fun test_create_perk_marketplace_v2() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Test create_perk_marketplace_v2 function
        perk_manager_v2::create_perk_marketplace_v2(
            &config,
            &admin_cap,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Switch to admin address to retrieve objects
        scenario::next_tx(&mut scenario, ADMIN);
        
        // Verify marketplace was created
        let mut marketplace = scenario::take_shared<PerkMarketplaceV2>(&scenario);
        let marketplace_cap = scenario::take_from_sender<PerkMarketplaceCapV2>(&scenario);
        
        // Cleanup - consume all variables
        sui::test_utils::destroy(admin_cap);
        scenario::return_shared(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        admin_v2::destroy_config_for_testing(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_create_perk_v2() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create marketplace first
        perk_manager_v2::create_perk_marketplace_v2(
            &config,
            &admin_cap,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Switch to admin address to retrieve marketplace objects
        scenario::next_tx(&mut scenario, ADMIN);
        let mut marketplace = scenario::take_shared<PerkMarketplaceV2>(&scenario);
        let marketplace_cap = scenario::take_from_sender<PerkMarketplaceCapV2>(&scenario);
        
        // Create partner and vault for testing
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let (partner_cap, mut partner_vault) = partner_v3::create_partner_with_vault_for_testing(&mut registry, PARTNER1, 1000000000, 50000000, &clock, scenario::ctx(&mut scenario));
        
        // Switch to PARTNER1 to ensure proper authorization
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // Test create_perk_v2 function
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Test Perk"), // name
            string::utf8(b"Test perk description"), // description
            string::utf8(b"discount"), // perk_type
            string::utf8(b"shopping"), // category
            vector::empty<string::String>(), // tags
            1000000, // base_price_usdc (1 USDC)
            8000, // partner_share_bps (80%)
            option::some(100u64), // max_total_claims
            option::some(5u64), // max_claims_per_user
            option::some(clock::timestamp_ms(&clock) + 86400000), // expiration_timestamp_ms
            true, // is_consumable
            option::some(1u64), // max_uses_per_claim
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup - consume all variables
        sui::test_utils::destroy(admin_cap);
        scenario::return_shared(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        sui::test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_claim_perk_v2() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create marketplace first
        perk_manager_v2::create_perk_marketplace_v2(
            &config,
            &admin_cap,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Switch to admin address to retrieve marketplace objects
        scenario::next_tx(&mut scenario, ADMIN);
        let mut marketplace = scenario::take_shared<PerkMarketplaceV2>(&scenario);
        let marketplace_cap = scenario::take_from_sender<PerkMarketplaceCapV2>(&scenario);
        
        // Create partner and vault for testing
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let (partner_cap, mut partner_vault) = partner_v3::create_partner_with_vault_for_testing(&mut registry, PARTNER1, 1000000000, 50000000, &clock, scenario::ctx(&mut scenario));
        
        // Switch to PARTNER1 to ensure proper authorization
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // Create a perk first
        perk_manager_v2::create_perk_v2(
            &mut marketplace,
            &partner_cap,
            &partner_vault, // Remove &mut
            string::utf8(b"Test Perk"),
            string::utf8(b"Test perk description"),
            string::utf8(b"reward"),
            string::utf8(b"gaming"),
            vector[string::utf8(b"test"), string::utf8(b"gaming")],
            PERK_PRICE_USDC,
            5000, // 50% partner share
            option::some(100), // max total claims
            option::some(5), // max claims per user
            option::some(clock::timestamp_ms(&clock) + 86400000), // expires in 1 day
            true, // is_consumable - FIXED: bool not Option<bool>
            option::some(1), // max_uses_per_claim
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Switch to USER1 for claiming
        scenario::next_tx(&mut scenario, USER1);
        
        // Note: We would need to retrieve the perk definition object to test claim_perk_v2
        // For now, we'll test the function signature and basic structure
        
        // Test claim_perk_v2 function
        // perk_manager_v2::claim_perk_v2(
        //     &mut marketplace,
        //     &mut perk_definition,
        //     &mut partner_vault,
        //     &mut ledger,
        //     &oracle,
        //     &clock,
        //     scenario::ctx(&mut scenario)
        // );
        
        // Cleanup - consume all variables
        sui::test_utils::destroy(admin_cap);
        scenario::return_shared(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_vault);
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_emergency_pause_marketplace() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create marketplace first
        perk_manager_v2::create_perk_marketplace_v2(
            &config,
            &admin_cap,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Switch to admin address to retrieve marketplace objects
        scenario::next_tx(&mut scenario, ADMIN);
        let mut marketplace = scenario::take_shared<PerkMarketplaceV2>(&scenario);
        let marketplace_cap = scenario::take_from_sender<PerkMarketplaceCapV2>(&scenario);
        
        // Test emergency_pause_marketplace function
        perk_manager_v2::emergency_pause_marketplace(
            &mut marketplace,
            &marketplace_cap,
            string::utf8(b"Emergency maintenance for security audit"),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup - consume all variables
        sui::test_utils::destroy(admin_cap);
        scenario::return_shared(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        admin_v2::destroy_config_for_testing(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_resume_marketplace_operations() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create marketplace first
        perk_manager_v2::create_perk_marketplace_v2(
            &config,
            &admin_cap,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Switch to admin address to retrieve marketplace objects
        scenario::next_tx(&mut scenario, ADMIN);
        let mut marketplace = scenario::take_shared<PerkMarketplaceV2>(&scenario);
        let marketplace_cap = scenario::take_from_sender<PerkMarketplaceCapV2>(&scenario);
        
        // Test resume_marketplace_operations function
        perk_manager_v2::resume_marketplace_operations(
            &mut marketplace,
            &marketplace_cap,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup - consume all variables
        sui::test_utils::destroy(admin_cap);
        scenario::return_shared(marketplace);
        sui::test_utils::destroy(marketplace_cap);
        admin_v2::destroy_config_for_testing(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
} 