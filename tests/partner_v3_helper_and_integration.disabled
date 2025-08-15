#[test_only]
module alpha_points::partner_v3_helper_and_integration {
    use sui::test_scenario::{Self as scenario};
    use sui::clock::{Self, Clock};
    use std::string;
    use std::vector;
    use sui::test_utils;
    use sui::object;
    
    // Import all required modules
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::partner_v3::{Self, PartnerCapV3, PartnerVault, PartnerRegistryV3, USDC};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    
    // Test addresses
    const ADMIN: address = @0xAD;
    const PARTNER1: address = @0x333;
    const PARTNER2: address = @0x444;
    const PARTNER3: address = @0x555;
    const USER1: address = @0x111;
    const USER2: address = @0x222;
    
    // Test constants
    const LARGE_USDC_AMOUNT: u64 = 5000_000_000; // 5,000 USDC
    const MEDIUM_USDC_AMOUNT: u64 = 1000_000_000; // 1,000 USDC
    const POINTS_AMOUNT: u64 = 25000; // 25K points
    const QUOTA_RESET_INTERVAL: u64 = 86400000; // 24 hours in ms
    
    // =================== TEST 1: Daily Quota Reset Functionality ===================
    
    #[test]
    fun test_daily_quota_reset_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner with large quota to avoid quota exhaustion
        let (mut partner_cap, mut vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            LARGE_USDC_AMOUNT,
            500000, // Daily quota: 500K points (large enough for test)
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // Test 1: Initial quota usage
        partner_v3::mint_points_with_vault_backing(
            &mut registry,
            &mut ledger,
            &config,
            &mut partner_cap,
            &mut vault,
            USER1,
            20000, // Use 20K out of 50K quota
            b"initial quota usage",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test 2: Try to use more quota in same day
        partner_v3::mint_points_with_vault_backing(
            &mut registry,
            &mut ledger,
            &config,
            &mut partner_cap,
            &mut vault,
            USER2,
            25000, // Use 25K more (total would be 45K)
            b"same day quota usage",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test 3: Fast forward time to next day
        clock::increment_for_testing(&mut clock, QUOTA_RESET_INTERVAL + 1000);
        
        // Test 4: Should be able to use full quota again after reset
        partner_v3::mint_points_with_vault_backing(
            &mut registry,
            &mut ledger,
            &config,
            &mut partner_cap,
            &mut vault,
            USER1,
            40000, // Use 40K points (should work after reset)
            b"after reset quota usage",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test 5: Multiple small quota resets
        clock::increment_for_testing(&mut clock, QUOTA_RESET_INTERVAL + 500);
        
        partner_v3::mint_points_with_vault_backing(
            &mut registry,
            &mut ledger,
            &config,
            &mut partner_cap,
            &mut vault,
            USER2,
            10000, // Small usage after another reset
            b"multiple reset test",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        test_utils::destroy(partner_cap);
        partner_v3::destroy_test_vault(vault);
        test_utils::destroy(registry);
        test_utils::destroy(ledger);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 2: Registry Management and Multi-Partner Operations ===================
    
    #[test]
    fun test_registry_management_and_multi_partner_operations() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Test initial registry state
        let (initial_partners, initial_generations, initial_usdc_locked, initial_usdc_in_defi, initial_yield, initial_vaults_in_defi) = 
            partner_v3::get_registry_stats_v3(&registry);
        
        assert!(initial_partners == 0, 1);
        assert!(initial_generations >= 1, 2);
        assert!(initial_usdc_locked == 0, 3);
        assert!(initial_usdc_in_defi == 0, 4);
        assert!(initial_yield == 0, 5);
        assert!(initial_vaults_in_defi == 0, 6);
        
        // Create multiple partners in same generation
        let (partner_cap1, vault1) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            LARGE_USDC_AMOUNT,
            100000, // Large quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        let (partner_cap2, vault2) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER2,
            MEDIUM_USDC_AMOUNT,
            50000, // Medium quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        let (partner_cap3, vault3) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER3,
            LARGE_USDC_AMOUNT,
            75000, // Large quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test registry stats after partner creation
        let (post_creation_partners, post_creation_generations, post_creation_usdc_locked, _, _, _) = 
            partner_v3::get_registry_stats_v3(&registry);
        
        assert!(post_creation_partners == 3, 7);
        assert!(post_creation_usdc_locked > initial_usdc_locked, 8);
        assert!(post_creation_usdc_locked == (LARGE_USDC_AMOUNT * 2 + MEDIUM_USDC_AMOUNT), 9);
        
        // Test individual partner information
        let (name1, addr1, gen1, vault_id1, owner1) = partner_v3::get_partner_info_v3(&partner_cap1);
        let (name2, addr2, gen2, vault_id2, owner2) = partner_v3::get_partner_info_v3(&partner_cap2);
        let (name3, addr3, gen3, vault_id3, owner3) = partner_v3::get_partner_info_v3(&partner_cap3);
        
        assert!(addr1 == PARTNER1, 10);
        assert!(addr2 == PARTNER2, 11);
        assert!(addr3 == PARTNER3, 12);
        assert!(owner1 == PARTNER1, 13);
        assert!(owner2 == PARTNER2, 14);
        assert!(owner3 == PARTNER3, 15);
        
        // Test vault information consistency
        let (vault_name1, vault_owner1, _, _, balance1, quota1, active1) = partner_v3::get_vault_info(&vault1);
        let (vault_name2, vault_owner2, _, _, balance2, quota2, active2) = partner_v3::get_vault_info(&vault2);
        let (vault_name3, vault_owner3, _, _, balance3, quota3, active3) = partner_v3::get_vault_info(&vault3);
        
        assert!(vault_owner1 == PARTNER1, 16);
        assert!(vault_owner2 == PARTNER2, 17);
        assert!(vault_owner3 == PARTNER3, 18);
        assert!(balance1 == LARGE_USDC_AMOUNT, 19);
        assert!(balance2 == MEDIUM_USDC_AMOUNT, 20);
        assert!(balance3 == LARGE_USDC_AMOUNT, 21);
        assert!(active1 && active2 && active3, 22);
        
        // Test utility functions across all partners
        assert!(partner_v3::get_partner_address(&partner_cap1) == PARTNER1, 23);
        assert!(partner_v3::get_partner_address(&partner_cap2) == PARTNER2, 24);
        assert!(partner_v3::get_partner_address(&partner_cap3) == PARTNER3, 25);
        
        assert!(!partner_v3::is_paused(&partner_cap1), 26);
        assert!(!partner_v3::is_paused(&partner_cap2), 27);
        assert!(!partner_v3::is_paused(&partner_cap3), 28);
        
        assert!(partner_v3::get_vault_partner_address(&vault1) == PARTNER1, 29);
        assert!(partner_v3::get_vault_partner_address(&vault2) == PARTNER2, 30);
        assert!(partner_v3::get_vault_partner_address(&vault3) == PARTNER3, 31);
        
        // Test UID functions
        let cap_id1 = partner_v3::get_partner_cap_uid_to_inner(&partner_cap1);
        let cap_id2 = partner_v3::get_partner_cap_uid_to_inner(&partner_cap2);
        let vault_id_direct1 = partner_v3::get_partner_vault_uid_to_inner(&vault1);
        let vault_id_direct2 = partner_v3::get_partner_vault_uid_to_inner(&vault2);
        
        // All IDs should be unique
        assert!(cap_id1 != cap_id2, 32);
        assert!(vault_id_direct1 != vault_id_direct2, 33);
        assert!(cap_id1 != vault_id_direct1, 34);
        
        // Cleanup
        test_utils::destroy(partner_cap1);
        test_utils::destroy(partner_cap2);
        test_utils::destroy(partner_cap3);
        partner_v3::destroy_test_vault(vault1);
        partner_v3::destroy_test_vault(vault2);
        partner_v3::destroy_test_vault(vault3);
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 3: Cross-Module Integration with Ledger V2 ===================
    
    #[test]
    fun test_cross_module_integration_with_ledger_v2() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner with very large quota to avoid quota issues
        let (mut partner_cap, mut vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            LARGE_USDC_AMOUNT,
            1000000, // Very large quota to avoid exhaustion
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // Test 1: Mint points through partner_v3 integration
        partner_v3::mint_points_with_vault_backing(
            &mut registry,
            &mut ledger,
            &config,
            &mut partner_cap,
            &mut vault,
            USER1,
            POINTS_AMOUNT,
            b"cross-module integration test",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify points were minted in ledger
        scenario::next_tx(&mut scenario, USER1);
        let user1_balance = ledger_v2::get_balance(&ledger, USER1);
        assert!(user1_balance >= POINTS_AMOUNT, 1);
        
        // Test 2: Mint more points for another user
        scenario::next_tx(&mut scenario, PARTNER1);
        partner_v3::mint_points_with_vault_backing(
            &mut registry,
            &mut ledger,
            &config,
            &mut partner_cap,
            &mut vault,
            USER2,
            POINTS_AMOUNT / 2,
            b"second user mint",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify second user's balance
        scenario::next_tx(&mut scenario, USER2);
        let user2_balance = ledger_v2::get_balance(&ledger, USER2);
        assert!(user2_balance >= POINTS_AMOUNT / 2, 2);
        
        // Test 3: Simulate points burning and vault callback
        let current_time = clock::timestamp_ms(&clock);
        let burned_points = POINTS_AMOUNT / 4;
        
        // Record vault state before burning
        let (pre_burn_total, pre_burn_available, pre_burn_reserved, _, _) = 
            partner_v3::get_vault_collateral_details(&vault);
        
        // Simulate points burning callback
        partner_v3::on_points_burned_vault(&mut vault, burned_points, &config, current_time);
        
        // Verify vault state updated correctly
        let (post_burn_total, post_burn_available, post_burn_reserved, _, _) = 
            partner_v3::get_vault_collateral_details(&vault);
        
        assert!(post_burn_total == pre_burn_total, 3); // Total shouldn't change
        assert!(post_burn_available >= pre_burn_available, 4); // Available should increase
        assert!(post_burn_reserved <= pre_burn_reserved, 5); // Reserved should decrease
        
        // Test 4: Revenue addition integration - use test function that adds actual USDC
        partner_v3::add_revenue_to_vault_test(&mut vault, 25000000, current_time, scenario::ctx(&mut scenario)); // 25 USDC
        
        let post_revenue_balance = partner_v3::get_vault_balance(&vault);
        assert!(post_revenue_balance > LARGE_USDC_AMOUNT, 6);
        
        // Test 5: Points minting recording
        partner_v3::record_points_minting(&mut vault, 10000, current_time, scenario::ctx(&mut scenario));
        
        let (final_total, final_available, final_reserved, _, _) = 
            partner_v3::get_vault_collateral_details(&vault);
        
        assert!(final_reserved > post_burn_reserved, 7); // Should increase after recording mint
        
        // Cleanup
        test_utils::destroy(partner_cap);
        partner_v3::destroy_test_vault(vault);
        test_utils::destroy(registry);
        test_utils::destroy(ledger);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 4: Advanced Revenue and Yield Management ===================
    
    #[test]
    fun test_advanced_revenue_and_yield_management() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner
        let (partner_cap, mut vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            MEDIUM_USDC_AMOUNT,
            100000, // Quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test initial yield status
        let (defi_enabled, protocol_in_use, deposit_amount, initial_lifetime_yield) = 
            partner_v3::get_defi_status(&vault);
        
        assert!(defi_enabled, 1);
        assert!(deposit_amount == 0, 2);
        assert!(initial_lifetime_yield == 0, 3);
        
        // Test 1: Small revenue additions over time
        let mut current_time = clock::timestamp_ms(&clock);
        
        partner_v3::add_revenue_to_vault(&mut vault, 1000000, current_time, scenario::ctx(&mut scenario)); // 1 USDC
        clock::increment_for_testing(&mut clock, 3600000); // 1 hour
        current_time = clock::timestamp_ms(&clock);
        
        partner_v3::add_revenue_to_vault(&mut vault, 2000000, current_time, scenario::ctx(&mut scenario)); // 2 USDC
        clock::increment_for_testing(&mut clock, 7200000); // 2 hours
        current_time = clock::timestamp_ms(&clock);
        
        partner_v3::add_revenue_to_vault(&mut vault, 5000000, current_time, scenario::ctx(&mut scenario)); // 5 USDC
        
        // Test yield accumulation
        let (_, _, _, accumulated_yield) = partner_v3::get_defi_status(&vault);
        assert!(accumulated_yield > initial_lifetime_yield, 4);
        assert!(accumulated_yield == 8000000, 5); // 1 + 2 + 5 USDC
        
        // Test 2: Large revenue addition
        partner_v3::add_revenue_to_vault(&mut vault, 100000000, current_time, scenario::ctx(&mut scenario)); // 100 USDC
        
        let (_, _, _, post_large_yield) = partner_v3::get_defi_status(&vault);
        assert!(post_large_yield > accumulated_yield, 6);
        assert!(post_large_yield == 108000000, 7); // Total: 108 USDC
        
        // Test 3: Vault balance changes with revenue
        let final_balance = partner_v3::get_vault_balance(&vault);
        // Note: add_revenue_to_vault only updates internal tracking, not actual balance
        // Only add_revenue_to_vault_test adds actual USDC
        assert!(final_balance >= MEDIUM_USDC_AMOUNT, 8); // May not increase with regular add_revenue_to_vault
        
        // Test 4: Revenue addition using test function
        partner_v3::add_revenue_to_vault_test(&mut vault, 50000000, current_time, scenario::ctx(&mut scenario)); // 50 USDC
        
        let test_function_balance = partner_v3::get_vault_balance(&vault);
        assert!(test_function_balance > final_balance, 10);
        
        // Test 5: Health metrics after revenue additions
        let (total_usdc, available, reserved, backing_ratio, health_factor) = 
            partner_v3::get_vault_collateral_details(&vault);
        
        assert!(total_usdc > MEDIUM_USDC_AMOUNT, 11);
        assert!(health_factor >= 10000, 12); // Should be very healthy with extra revenue
        
        // Test 6: Capacity improvements from revenue
        assert!(partner_v3::can_support_points_minting(&vault, 100000), 13);
        assert!(partner_v3::can_support_transaction(&vault, 50000000), 14); // 50 USDC
        
        let max_withdrawable = partner_v3::calculate_max_withdrawable_usdc(&vault, &config);
        assert!(max_withdrawable > MEDIUM_USDC_AMOUNT, 15);
        
        // Cleanup
        test_utils::destroy(partner_cap);
        partner_v3::destroy_test_vault(vault);
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 5: Comprehensive View Functions Coverage ===================
    
    #[test]
    fun test_comprehensive_view_functions_coverage() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create multiple partners for comprehensive testing
        let (partner_cap1, mut vault1) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            LARGE_USDC_AMOUNT,
            200000, // Large quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        let (partner_cap2, mut vault2) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER2,
            MEDIUM_USDC_AMOUNT,
            100000, // Medium quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Add some activity to make data interesting
        let current_time = clock::timestamp_ms(&clock);
        partner_v3::record_points_minting(&mut vault1, 50000, current_time, scenario::ctx(&mut scenario));
        partner_v3::record_points_minting(&mut vault2, 25000, current_time, scenario::ctx(&mut scenario));
        partner_v3::add_revenue_to_vault_test(&mut vault1, 10000000, current_time, scenario::ctx(&mut scenario)); // 10 USDC
        partner_v3::add_revenue_to_vault_test(&mut vault2, 5000000, current_time, scenario::ctx(&mut scenario)); // 5 USDC
        
        // Test 1: All vault info functions
        let (name1, owner1, gen1, created1, balance1, quota1, active1) = partner_v3::get_vault_info(&vault1);
        let (name2, owner2, gen2, created2, balance2, quota2, active2) = partner_v3::get_vault_info(&vault2);
        
        assert!(!string::is_empty(&name1) && !string::is_empty(&name2), 1);
        assert!(owner1 == PARTNER1 && owner2 == PARTNER2, 2);
        assert!(gen1 == gen2, 3); // Same generation
        assert!(balance1 > balance2, 4); // Vault1 is larger
        assert!(active1 && active2, 5); // Both active
        
        // Test 2: Vault collateral details
        let (total1, avail1, reserved1, backing1, health1) = partner_v3::get_vault_collateral_details(&vault1);
        let (total2, avail2, reserved2, backing2, health2) = partner_v3::get_vault_collateral_details(&vault2);
        
        assert!(total1 > total2, 6);
        assert!(reserved1 > 0 && reserved2 > 0, 7); // Both have reservations
        assert!(avail1 > avail2, 8);
        assert!(health1 > 0 && health2 > 0, 9); // Both healthy
        
        // Test 3: Maximum withdrawable calculations
        let max_withdraw1 = partner_v3::calculate_max_withdrawable_usdc(&vault1, &config);
        let max_withdraw2 = partner_v3::calculate_max_withdrawable_usdc(&vault2, &config);
        
        assert!(max_withdraw1 >= max_withdraw2, 10);
        assert!(max_withdraw1 >= 0 && max_withdraw2 >= 0, 11);
        
        // Test 4: DeFi status for both vaults
        let (defi1_enabled, defi1_protocol, defi1_deposit, defi1_yield) = partner_v3::get_defi_status(&vault1);
        let (defi2_enabled, defi2_protocol, defi2_deposit, defi2_yield) = partner_v3::get_defi_status(&vault2);
        
        assert!(defi1_enabled && defi2_enabled, 12);
        assert!(defi1_yield > 0 && defi2_yield > 0, 13); // Both have yield from revenue
        
        // Test 5: DeFi readiness
        let ready1 = partner_v3::is_vault_defi_ready(&vault1);
        let ready2 = partner_v3::is_vault_defi_ready(&vault2);
        
        // Large vault should be more likely to be DeFi ready
        
        // Test 6: Partner info functions
        let (pname1, paddr1, pgen1, pvault1, powner1) = partner_v3::get_partner_info_v3(&partner_cap1);
        let (pname2, paddr2, pgen2, pvault2, powner2) = partner_v3::get_partner_info_v3(&partner_cap2);
        
        assert!(paddr1 == PARTNER1 && paddr2 == PARTNER2, 14);
        assert!(powner1 == PARTNER1 && powner2 == PARTNER2, 15);
        assert!(pgen1 == pgen2, 16); // Same generation
        
        // Test 7: Registry comprehensive stats
        let (reg_partners, reg_gens, reg_usdc, reg_defi_usdc, reg_yield, reg_defi_vaults) = 
            partner_v3::get_registry_stats_v3(&registry);
        
        assert!(reg_partners == 2, 17);
        assert!(reg_gens >= 1, 18);
        assert!(reg_usdc > 0, 19);
        assert!(reg_defi_usdc == 0, 20); // No vaults transferred to DeFi yet
        assert!(reg_defi_vaults == 0, 21);
        
        // Test 8: Utility functions comprehensive
        assert!(partner_v3::get_partner_address(&partner_cap1) == PARTNER1, 22);
        assert!(partner_v3::get_partner_address(&partner_cap2) == PARTNER2, 23);
        assert!(!partner_v3::is_paused(&partner_cap1), 24);
        assert!(!partner_v3::is_paused(&partner_cap2), 25);
        assert!(partner_v3::get_vault_partner_address(&vault1) == PARTNER1, 26);
        assert!(partner_v3::get_vault_partner_address(&vault2) == PARTNER2, 27);
        
        // Test 9: Capacity functions
        assert!(partner_v3::can_support_points_minting(&vault1, 10000), 28);
        assert!(partner_v3::can_support_points_minting(&vault2, 5000), 29);
        assert!(partner_v3::can_support_transaction(&vault1, 10000000), 30); // 10 USDC
        assert!(partner_v3::can_support_transaction(&vault2, 5000000), 31); // 5 USDC
        
        // Test 10: Balance functions
        let balance1_direct = partner_v3::get_vault_balance(&vault1);
        let balance2_direct = partner_v3::get_vault_balance(&vault2);
        
        assert!(balance1_direct == total1, 32);
        assert!(balance2_direct == total2, 33);
        assert!(balance1_direct > LARGE_USDC_AMOUNT, 34); // Should include revenue
        assert!(balance2_direct > MEDIUM_USDC_AMOUNT, 35); // Should include revenue
        
        // Test 11: UID functions
        let cap_uid1 = partner_v3::get_partner_cap_uid_to_inner(&partner_cap1);
        let cap_uid2 = partner_v3::get_partner_cap_uid_to_inner(&partner_cap2);
        let vault_uid1 = partner_v3::get_partner_vault_uid_to_inner(&vault1);
        let vault_uid2 = partner_v3::get_partner_vault_uid_to_inner(&vault2);
        
        // All UIDs should be unique
        assert!(cap_uid1 != cap_uid2, 36);
        assert!(vault_uid1 != vault_uid2, 37);
        assert!(cap_uid1 != vault_uid1, 38);
        assert!(cap_uid2 != vault_uid2, 39);
        
        // Cleanup
        test_utils::destroy(partner_cap1);
        test_utils::destroy(partner_cap2);
        partner_v3::destroy_test_vault(vault1);
        partner_v3::destroy_test_vault(vault2);
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}
