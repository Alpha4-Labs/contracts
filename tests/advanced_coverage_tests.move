#[test_only]
#[allow(unused_use, unused_const, unused_let_mut, duplicate_alias)]
module alpha_points::advanced_coverage_tests {
    use sui::test_scenario::{Self as scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::object::{Self, ID};
    use sui::test_utils;
    use std::string::{Self, String};
    use std::option::{Self};
    
    use alpha_points::admin_simple::{Self, ConfigSimple, AdminCapSimple};
    use alpha_points::ledger_simple::{Self, LedgerSimple};
    use alpha_points::oracle_simple::{Self, OracleSimple, OracleCapSimple};
    use alpha_points::partner_simple::{Self, PartnerRegistrySimple, PartnerCapSimple, PartnerVaultSimple, USDC};
    use alpha_points::integration_simple::{Self};
    use alpha_points::perk_simple::{Self, PerkMarketplaceSimple, PerkSimple};
    use alpha_points::generation_simple::{Self, IntegrationRegistrySimple, PartnerIntegrationSimple, RegisteredActionSimple};
    
    const ADMIN: address = @0x123;
    const PARTNER1: address = @0x456;
    const USER1: address = @0x789;
    const USER2: address = @0xabc;
    
    // =================== ADVANCED PERK COVERAGE ===================
    
    #[test]
    fun test_perk_marketplace_creation() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin infrastructure
        let admin_cap = admin_simple::create_test_admin_cap(scenario::ctx(&mut scenario));
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        
        // Test marketplace creation entry function (not tested before)
        perk_simple::create_perk_marketplace_simple(
            &config,
            &admin_cap,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, ADMIN);
        let marketplace = scenario::take_shared<PerkMarketplaceSimple>(&scenario);
        
        // Test marketplace stats after creation
        let (total_perks, total_claims, total_revenue) = perk_simple::get_marketplace_stats(&marketplace);
        assert!(total_perks == 0, 1);
        assert!(total_claims == 0, 2);
        assert!(total_revenue == 0, 3);
        
        // Cleanup
        scenario::return_shared(marketplace);
        admin_simple::destroy_test_admin_cap(admin_cap);
        admin_simple::destroy_test_config(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_perk_creation_and_deactivation() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create test perk using test helper
        let mut perk = perk_simple::create_test_perk(
            string::utf8(b"Premium Coffee"),
            1500, // 15 USDC base price
            2500, // 25% partner share (2500 bps)
            scenario::ctx(&mut scenario)
        );
        
        // Test perk info after creation
        let (name, base_price, current_price_points, is_active) = perk_simple::get_perk_info(&perk);
        assert!(name == string::utf8(b"Premium Coffee"), 1);
        assert!(base_price == 1500, 2);
        assert!(current_price_points > 0, 3); // Should have calculated points price
        assert!(is_active, 4);
        
        // Test perk revenue info before claims
        let (claims_before, revenue_before, usdc_before, partner_before) = perk_simple::get_perk_revenue_info(&perk);
        assert!(claims_before == 0, 5);
        assert!(revenue_before == 0, 6);
        assert!(usdc_before == 0, 7);
        assert!(partner_before == 0, 8);
        
        // Create admin infrastructure for deactivation
        let admin_cap = admin_simple::create_test_admin_cap(scenario::ctx(&mut scenario));
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        
        // Test perk deactivation entry function (not tested before)
        perk_simple::deactivate_perk(
            &mut perk,
            &config,
            &admin_cap,
            scenario::ctx(&mut scenario)
        );
        
        // Test that perk is now inactive
        let (_, _, _, is_active_after) = perk_simple::get_perk_info(&perk);
        assert!(!is_active_after, 9);
        
        // Cleanup
        perk_simple::destroy_test_perk(perk);
        admin_simple::destroy_test_admin_cap(admin_cap);
        admin_simple::destroy_test_config(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== ADVANCED GENERATION COVERAGE ===================
    
    #[test]
    fun test_integration_registry_creation() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin infrastructure
        let admin_cap = admin_simple::create_test_admin_cap(scenario::ctx(&mut scenario));
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        
        // Test integration registry creation entry function (not tested before)
        generation_simple::create_integration_registry_simple(
            &config,
            &admin_cap,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, ADMIN);
        let registry = scenario::take_shared<IntegrationRegistrySimple>(&scenario);
        
        // Test that registry was created successfully
        // (No direct getters, but we can test that it exists by taking it)
        
        // Cleanup
        scenario::return_shared(registry);
        admin_simple::destroy_test_admin_cap(admin_cap);
        admin_simple::destroy_test_config(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_integration_and_action_info() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create test integration using test helper
        let dummy_cap_id = object::id_from_address(@0x1);
        let integration = generation_simple::create_test_integration(
            dummy_cap_id,
            string::utf8(b"Mobile Gaming App"),
            scenario::ctx(&mut scenario)
        );
        
        // Test integration info after creation
        let (integration_name, is_active, active_actions) = generation_simple::get_integration_info(&integration);
        assert!(integration_name == string::utf8(b"Mobile Gaming App"), 1);
        assert!(is_active, 2);
        assert!(active_actions == 0, 3); // No actions registered yet
        
        // Test can execute action function with a mock action
        // (We can't easily create a real action without full infrastructure)
        // So we'll test the function exists by testing the helper functions
        
        // Cleanup
        generation_simple::destroy_test_integration(integration);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== ADVANCED PARTNER COVERAGE ===================
    
    #[test]
    fun test_partner_registry_creation() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin infrastructure
        let admin_cap = admin_simple::create_test_admin_cap(scenario::ctx(&mut scenario));
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        
        // Test partner registry creation entry function (not tested before)
        partner_simple::create_partner_registry_simple(
            &config,
            &admin_cap,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, ADMIN);
        let registry = scenario::take_shared<PartnerRegistrySimple>(&scenario);
        
        // Test that registry was created successfully
        // (No direct getters, but we can test that it exists by taking it)
        
        // Cleanup
        scenario::return_shared(registry);
        admin_simple::destroy_test_admin_cap(admin_cap);
        admin_simple::destroy_test_config(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_partner_quota_and_pause_functions() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create partner and vault using test helper
        let (mut partner_cap, partner_vault) = partner_simple::create_test_partner_and_vault(
            string::utf8(b"Test Partner"),
            75000, // 75K USDC
            scenario::ctx(&mut scenario)
        );
        
        // Test initial quota info
        let (total_quota_before, used_quota_before) = partner_simple::get_quota_info(&partner_cap);
        assert!(total_quota_before > 0, 1);
        assert!(used_quota_before == 0, 2);
        
        // Test can mint points function (not tested before)
        assert!(partner_simple::can_mint_points(&partner_vault, 50000), 3); // Should be able to mint 50K
        assert!(!partner_simple::can_mint_points(&partner_vault, 10000000), 4); // Should not be able to mint 10M
        
        // Test vault info
        let (usdc_balance, reserved_backing, available_withdrawal) = partner_simple::get_vault_info(&partner_vault);
        assert!(usdc_balance == 0, 5); // Test helper sets balance to zero
        assert!(reserved_backing == 0, 6); // Initially no backing reserved
        assert!(available_withdrawal == 75000, 7); // Available amount should match
        
        // Test partner pause functionality entry function (not tested before)
        let admin_cap = admin_simple::create_test_admin_cap(scenario::ctx(&mut scenario));
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        
        // Test is paused function before pause
        assert!(!partner_simple::is_paused(&partner_cap), 8);
        
        partner_simple::set_partner_pause(
            &config,
            &admin_cap,
            &mut partner_cap,
            true,
            scenario::ctx(&mut scenario)
        );
        
        // Test is paused function after pause
        assert!(partner_simple::is_paused(&partner_cap), 9);
        
        // Test unpause
        partner_simple::set_partner_pause(
            &config,
            &admin_cap,
            &mut partner_cap,
            false,
            scenario::ctx(&mut scenario)
        );
        
        // Test is paused function after unpause
        assert!(!partner_simple::is_paused(&partner_cap), 10);
        
        // Cleanup
        partner_simple::destroy_test_partner_cap(partner_cap);
        partner_simple::destroy_test_vault(partner_vault);
        admin_simple::destroy_test_admin_cap(admin_cap);
        admin_simple::destroy_test_config(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_partner_address_and_id_functions() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create multiple partners to test address functions
        let (partner1_cap, partner1_vault) = partner_simple::create_test_partner_and_vault(
            string::utf8(b"Partner One"),
            25000,
            scenario::ctx(&mut scenario)
        );
        
        let (partner2_cap, partner2_vault) = partner_simple::create_test_partner_and_vault(
            string::utf8(b"Partner Two"),
            35000,
            scenario::ctx(&mut scenario)
        );
        
        // Test get partner address functions (comprehensive testing)
        let partner1_addr = partner_simple::get_partner_address(&partner1_cap);
        let partner2_addr = partner_simple::get_partner_address(&partner2_cap);
        let vault1_addr = partner_simple::get_vault_partner_address(&partner1_vault);
        let vault2_addr = partner_simple::get_vault_partner_address(&partner2_vault);
        
        // Verify addresses match between cap and vault
        assert!(partner1_addr == vault1_addr, 1);
        assert!(partner2_addr == vault2_addr, 2);
        
        // Test is paused function (comprehensive testing)
        assert!(!partner_simple::is_paused(&partner1_cap), 3);
        assert!(!partner_simple::is_paused(&partner2_cap), 4);
        
        // Test UID to inner functions (not tested before)
        let cap1_id = partner_simple::get_partner_cap_uid_to_inner(&partner1_cap);
        let cap2_id = partner_simple::get_partner_cap_uid_to_inner(&partner2_cap);
        let vault1_id = partner_simple::get_partner_vault_uid_to_inner(&partner1_vault);
        let vault2_id = partner_simple::get_partner_vault_uid_to_inner(&partner2_vault);
        
        // Verify all IDs are different
        assert!(cap1_id != cap2_id, 5);
        assert!(vault1_id != vault2_id, 6);
        assert!(cap1_id != vault1_id, 7);
        assert!(cap2_id != vault2_id, 8);
        
        // Cleanup
        partner_simple::destroy_test_partner_cap(partner1_cap);
        partner_simple::destroy_test_vault(partner1_vault);
        partner_simple::destroy_test_partner_cap(partner2_cap);
        partner_simple::destroy_test_vault(partner2_vault);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}
