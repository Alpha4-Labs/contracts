#[test_only]
#[allow(unused_use, unused_const, unused_let_mut, duplicate_alias)]
module alpha_points::perk_focused_tests {
    use sui::test_scenario::{Self as scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::object::{Self, ID};
    use sui::test_utils;
    use std::string::{Self, String};
    use std::option::{Self};
    
    use alpha_points::admin_simple::{Self, ConfigSimple, AdminCapSimple};
    use alpha_points::ledger_simple::{Self, LedgerSimple};
    use alpha_points::oracle_simple::{Self, OracleSimple};
    use alpha_points::partner_simple::{Self, PartnerCapSimple, PartnerVaultSimple, USDC};
    use alpha_points::perk_simple::{Self, PerkMarketplaceSimple, PerkSimple};
    
    const ADMIN: address = @0x123;
    const PARTNER1: address = @0x456;
    const USER1: address = @0x789;
    const USER2: address = @0xabc;
    
    // =================== COMPREHENSIVE PERK SIMPLE COVERAGE ===================
    
    #[test]
    fun test_init_for_testing_function() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test init_for_testing function (not tested before)
        perk_simple::init_for_testing(scenario::ctx(&mut scenario));
        
        // The function should complete without errors
        // (We can't easily test the shared object creation in this context)
        
        // Cleanup
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_marketplace_pause_function_exists() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test set_marketplace_pause function exists by testing with simple setup
        // Since we can't easily create shared marketplace objects in this context,
        // we'll focus on testing that the function can be referenced and exists
        
        // Create simple infrastructure for testing
        let admin_cap = admin_simple::create_test_admin_cap(scenario::ctx(&mut scenario));
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        
        // Create marketplace using entry function
        perk_simple::create_perk_marketplace_simple(
            &config,
            &admin_cap,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, ADMIN);
        let mut marketplace = scenario::take_shared<PerkMarketplaceSimple>(&scenario);
        
        // Test set_marketplace_pause functionality (not fully tested before)
        
        // Test pause
        perk_simple::set_marketplace_pause(
            &mut marketplace,
            &config,
            &admin_cap,
            true,
            scenario::ctx(&mut scenario)
        );
        
        // Test unpause
        perk_simple::set_marketplace_pause(
            &mut marketplace,
            &config,
            &admin_cap,
            false,
            scenario::ctx(&mut scenario)
        );
        
        // Test multiple pause/unpause cycles
        perk_simple::set_marketplace_pause(
            &mut marketplace,
            &config,
            &admin_cap,
            true,
            scenario::ctx(&mut scenario)
        );
        
        perk_simple::set_marketplace_pause(
            &mut marketplace,
            &config,
            &admin_cap,
            false,
            scenario::ctx(&mut scenario)
        );
        
        // Test final state - marketplace should be operational
        let (total_perks, total_claims, total_revenue) = perk_simple::get_marketplace_stats(&marketplace);
        assert!(total_perks == 0, 1); // Should start with 0 perks
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
    fun test_perk_info_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test get_perk_info with various perk configurations
        
        // Test perk 1: Basic configuration
        let perk1 = perk_simple::create_test_perk(
            string::utf8(b"Basic Coffee"),
            500, // 5 USDC base price
            1000, // 10% partner share (1000 bps)
            scenario::ctx(&mut scenario)
        );
        
        let (name1, base_price1, current_price_points1, is_active1) = perk_simple::get_perk_info(&perk1);
        assert!(name1 == string::utf8(b"Basic Coffee"), 1);
        assert!(base_price1 == 500, 2);
        assert!(current_price_points1 == 500000, 3); // 500 USDC * 1000 points per USDC
        assert!(is_active1, 4);
        
        // Test perk 2: High value configuration
        let perk2 = perk_simple::create_test_perk(
            string::utf8(b"Premium Experience"),
            5000, // 50 USDC base price
            2500, // 25% partner share (2500 bps)
            scenario::ctx(&mut scenario)
        );
        
        let (name2, base_price2, current_price_points2, is_active2) = perk_simple::get_perk_info(&perk2);
        assert!(name2 == string::utf8(b"Premium Experience"), 5);
        assert!(base_price2 == 5000, 6);
        assert!(current_price_points2 == 5000000, 7); // 5000 USDC * 1000 points per USDC
        assert!(is_active2, 8);
        
        // Test perk 3: Minimal configuration
        let perk3 = perk_simple::create_test_perk(
            string::utf8(b"A"),
            1, // 0.01 USDC base price
            1, // 0.01% partner share (1 bps)
            scenario::ctx(&mut scenario)
        );
        
        let (name3, base_price3, current_price_points3, is_active3) = perk_simple::get_perk_info(&perk3);
        assert!(name3 == string::utf8(b"A"), 9);
        assert!(base_price3 == 1, 10);
        assert!(current_price_points3 == 1000, 11); // 1 USDC * 1000 points per USDC
        assert!(is_active3, 12);
        
        // Test that all perks are different
        assert!(name1 != name2, 13);
        assert!(name2 != name3, 14);
        assert!(name1 != name3, 15);
        assert!(base_price1 != base_price2, 16);
        assert!(base_price2 != base_price3, 17);
        
        // Cleanup
        perk_simple::destroy_test_perk(perk1);
        perk_simple::destroy_test_perk(perk2);
        perk_simple::destroy_test_perk(perk3);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_perk_revenue_info_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test get_perk_revenue_info with multiple perks
        
        // Create perks with different configurations
        let perk1 = perk_simple::create_test_perk(
            string::utf8(b"Revenue Test 1"),
            1000, // 10 USDC
            1500, // 15% partner share
            scenario::ctx(&mut scenario)
        );
        
        let perk2 = perk_simple::create_test_perk(
            string::utf8(b"Revenue Test 2"),
            2000, // 20 USDC
            3000, // 30% partner share
            scenario::ctx(&mut scenario)
        );
        
        // Test initial revenue info for both perks
        let (claims1_before, revenue1_before, usdc1_before, partner1_before) = perk_simple::get_perk_revenue_info(&perk1);
        let (claims2_before, revenue2_before, usdc2_before, partner2_before) = perk_simple::get_perk_revenue_info(&perk2);
        
        // All should start at zero
        assert!(claims1_before == 0, 1);
        assert!(revenue1_before == 0, 2);
        assert!(usdc1_before == 0, 3);
        assert!(partner1_before == 0, 4);
        
        assert!(claims2_before == 0, 5);
        assert!(revenue2_before == 0, 6);
        assert!(usdc2_before == 0, 7);
        assert!(partner2_before == 0, 8);
        
        // Verify both perks have same initial state
        assert!(claims1_before == claims2_before, 9);
        assert!(revenue1_before == revenue2_before, 10);
        assert!(usdc1_before == usdc2_before, 11);
        assert!(partner1_before == partner2_before, 12);
        
        // Test perk info to verify they're different perks
        let (name1, price1, points1, active1) = perk_simple::get_perk_info(&perk1);
        let (name2, price2, points2, active2) = perk_simple::get_perk_info(&perk2);
        
        assert!(name1 != name2, 13);
        assert!(price1 != price2, 14);
        assert!(points1 != points2, 15);
        assert!(active1 && active2, 16);
        
        // Cleanup
        perk_simple::destroy_test_perk(perk1);
        perk_simple::destroy_test_perk(perk2);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_marketplace_stats_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create marketplace
        let admin_cap = admin_simple::create_test_admin_cap(scenario::ctx(&mut scenario));
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        
        perk_simple::create_perk_marketplace_simple(
            &config,
            &admin_cap,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, ADMIN);
        let marketplace = scenario::take_shared<PerkMarketplaceSimple>(&scenario);
        
        // Test get_marketplace_stats with empty marketplace
        let (total_perks_empty, total_claims_empty, total_revenue_empty) = perk_simple::get_marketplace_stats(&marketplace);
        assert!(total_perks_empty == 0, 1);
        assert!(total_claims_empty == 0, 2);
        assert!(total_revenue_empty == 0, 3);
        
        // Test marketplace stats remain consistent
        let (perks_check, claims_check, revenue_check) = perk_simple::get_marketplace_stats(&marketplace);
        assert!(perks_check == total_perks_empty, 4);
        assert!(claims_check == total_claims_empty, 5);
        assert!(revenue_check == total_revenue_empty, 6);
        
        // Test multiple calls return same results
        let (perks_final, claims_final, revenue_final) = perk_simple::get_marketplace_stats(&marketplace);
        assert!(perks_final == 0, 7);
        assert!(claims_final == 0, 8);
        assert!(revenue_final == 0, 9);
        
        // Cleanup
        scenario::return_shared(marketplace);
        admin_simple::destroy_test_admin_cap(admin_cap);
        admin_simple::destroy_test_config(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_perk_deactivation_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create multiple perks for deactivation testing
        let mut perk1 = perk_simple::create_test_perk(
            string::utf8(b"Deactivation Test 1"),
            1000,
            1500,
            scenario::ctx(&mut scenario)
        );
        
        let mut perk2 = perk_simple::create_test_perk(
            string::utf8(b"Deactivation Test 2"),
            2000,
            2000,
            scenario::ctx(&mut scenario)
        );
        
        let mut perk3 = perk_simple::create_test_perk(
            string::utf8(b"Deactivation Test 3"),
            3000,
            2500,
            scenario::ctx(&mut scenario)
        );
        
        // Verify all perks start active
        let (_, _, _, active1_before) = perk_simple::get_perk_info(&perk1);
        let (_, _, _, active2_before) = perk_simple::get_perk_info(&perk2);
        let (_, _, _, active3_before) = perk_simple::get_perk_info(&perk3);
        
        assert!(active1_before, 1);
        assert!(active2_before, 2);
        assert!(active3_before, 3);
        
        // Create admin infrastructure for deactivation
        let admin_cap = admin_simple::create_test_admin_cap(scenario::ctx(&mut scenario));
        let config = admin_simple::create_test_config(scenario::ctx(&mut scenario));
        
        // Test deactivate_perk on first perk
        perk_simple::deactivate_perk(
            &mut perk1,
            &config,
            &admin_cap,
            scenario::ctx(&mut scenario)
        );
        
        // Verify only perk1 is deactivated
        let (_, _, _, active1_after) = perk_simple::get_perk_info(&perk1);
        let (_, _, _, active2_after) = perk_simple::get_perk_info(&perk2);
        let (_, _, _, active3_after) = perk_simple::get_perk_info(&perk3);
        
        assert!(!active1_after, 4); // Should be inactive
        assert!(active2_after, 5); // Should still be active
        assert!(active3_after, 6); // Should still be active
        
        // Test deactivating remaining perks
        perk_simple::deactivate_perk(
            &mut perk2,
            &config,
            &admin_cap,
            scenario::ctx(&mut scenario)
        );
        
        perk_simple::deactivate_perk(
            &mut perk3,
            &config,
            &admin_cap,
            scenario::ctx(&mut scenario)
        );
        
        // Verify all perks are now inactive
        let (_, _, _, final_active1) = perk_simple::get_perk_info(&perk1);
        let (_, _, _, final_active2) = perk_simple::get_perk_info(&perk2);
        let (_, _, _, final_active3) = perk_simple::get_perk_info(&perk3);
        
        assert!(!final_active1, 7);
        assert!(!final_active2, 8);
        assert!(!final_active3, 9);
        
        // Cleanup
        perk_simple::destroy_test_perk(perk1);
        perk_simple::destroy_test_perk(perk2);
        perk_simple::destroy_test_perk(perk3);
        admin_simple::destroy_test_admin_cap(admin_cap);
        admin_simple::destroy_test_config(config);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_perk_name_variations() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test create_test_perk with various name patterns (enhanced testing)
        
        // Test minimal name
        let perk1 = perk_simple::create_test_perk(
            string::utf8(b"X"),
            100,
            500,
            scenario::ctx(&mut scenario)
        );
        
        // Test long name
        let perk2 = perk_simple::create_test_perk(
            string::utf8(b"Super Premium Ultra Deluxe Coffee Experience With Extra Benefits And More"),
            5000,
            3000,
            scenario::ctx(&mut scenario)
        );
        
        // Test special characters
        let perk3 = perk_simple::create_test_perk(
            string::utf8(b"Coffee & Tea - Special Deal! 50% Off"),
            1500,
            2000,
            scenario::ctx(&mut scenario)
        );
        
        // Test numeric name
        let perk4 = perk_simple::create_test_perk(
            string::utf8(b"12345 Points Special Offer 2024"),
            2500,
            1800,
            scenario::ctx(&mut scenario)
        );
        
        // Verify all perks have correct names
        let (name1, _, _, _) = perk_simple::get_perk_info(&perk1);
        let (name2, _, _, _) = perk_simple::get_perk_info(&perk2);
        let (name3, _, _, _) = perk_simple::get_perk_info(&perk3);
        let (name4, _, _, _) = perk_simple::get_perk_info(&perk4);
        
        assert!(name1 == string::utf8(b"X"), 1);
        assert!(name2 == string::utf8(b"Super Premium Ultra Deluxe Coffee Experience With Extra Benefits And More"), 2);
        assert!(name3 == string::utf8(b"Coffee & Tea - Special Deal! 50% Off"), 3);
        assert!(name4 == string::utf8(b"12345 Points Special Offer 2024"), 4);
        
        // Verify all names are unique
        assert!(name1 != name2, 5);
        assert!(name2 != name3, 6);
        assert!(name3 != name4, 7);
        assert!(name1 != name3, 8);
        assert!(name1 != name4, 9);
        assert!(name2 != name4, 10);
        
        // Cleanup
        perk_simple::destroy_test_perk(perk1);
        perk_simple::destroy_test_perk(perk2);
        perk_simple::destroy_test_perk(perk3);
        perk_simple::destroy_test_perk(perk4);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_perk_price_variations() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test create_test_perk with various price configurations (enhanced testing)
        
        // Test minimal price
        let perk1 = perk_simple::create_test_perk(
            string::utf8(b"Minimal Price"),
            1, // 0.01 USDC
            1, // 0.01% partner share
            scenario::ctx(&mut scenario)
        );
        
        // Test medium price
        let perk2 = perk_simple::create_test_perk(
            string::utf8(b"Medium Price"),
            1000, // 10 USDC
            1500, // 15% partner share
            scenario::ctx(&mut scenario)
        );
        
        // Test high price
        let perk3 = perk_simple::create_test_perk(
            string::utf8(b"High Price"),
            10000, // 100 USDC
            5000, // 50% partner share
            scenario::ctx(&mut scenario)
        );
        
        // Test maximum reasonable price
        let perk4 = perk_simple::create_test_perk(
            string::utf8(b"Premium Price"),
            100000, // 1000 USDC
            9999, // 99.99% partner share
            scenario::ctx(&mut scenario)
        );
        
        // Verify all perks have correct prices
        let (_, price1, points1, _) = perk_simple::get_perk_info(&perk1);
        let (_, price2, points2, _) = perk_simple::get_perk_info(&perk2);
        let (_, price3, points3, _) = perk_simple::get_perk_info(&perk3);
        let (_, price4, points4, _) = perk_simple::get_perk_info(&perk4);
        
        assert!(price1 == 1, 1);
        assert!(price2 == 1000, 2);
        assert!(price3 == 10000, 3);
        assert!(price4 == 100000, 4);
        
        // Verify points pricing (price * 1000)
        assert!(points1 == 1000, 5); // 1 USDC * 1000
        assert!(points2 == 1000000, 6); // 1000 USDC * 1000
        assert!(points3 == 10000000, 7); // 10000 USDC * 1000
        assert!(points4 == 100000000, 8); // 100000 USDC * 1000
        
        // Verify prices are different
        assert!(price1 != price2, 9);
        assert!(price2 != price3, 10);
        assert!(price3 != price4, 11);
        
        // Verify price ordering
        assert!(price1 < price2, 12);
        assert!(price2 < price3, 13);
        assert!(price3 < price4, 14);
        
        // Cleanup
        perk_simple::destroy_test_perk(perk1);
        perk_simple::destroy_test_perk(perk2);
        perk_simple::destroy_test_perk(perk3);
        perk_simple::destroy_test_perk(perk4);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}
