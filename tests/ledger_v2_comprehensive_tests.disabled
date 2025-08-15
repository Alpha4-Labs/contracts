#[test_only]
module alpha_points::ledger_v2_comprehensive_tests {
    use sui::test_scenario::{Self as scenario};
    use sui::clock;
    use sui::transfer;
    
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    const USER2: address = @0xC;
    const USER3: address = @0xD;
    
    #[test]
    fun test_comprehensive_point_type_functions() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Test ALL point type functions for coverage
        let staking_type = ledger_v2::staking_reward_type();
        let governance_type = ledger_v2::governance_reward_type();
        let referral_type = ledger_v2::referral_bonus_type();
        let liquidity_type = ledger_v2::liquidity_mining_type();
        let loan_type = ledger_v2::loan_collateral_type();
        let emergency_type = ledger_v2::emergency_mint_type();
        let partner_type = ledger_v2::partner_reward_type();
        
        // Test new point type functions
        let new_staking = ledger_v2::new_staking_reward();
        let new_loan = ledger_v2::new_loan_collateral();
        let new_partner = ledger_v2::new_partner_reward();
        let new_referral = ledger_v2::new_referral_bonus();
        let new_liquidity = ledger_v2::new_liquidity_mining();
        let new_governance = ledger_v2::new_governance_reward();
        
        // Verify all types are valid
        assert!(staking_type == new_staking, 1);
        assert!(loan_type == new_loan, 2);
        assert!(partner_type == new_partner, 3);
        assert!(referral_type == new_referral, 4);
        assert!(liquidity_type == new_liquidity, 5);
        assert!(governance_type == new_governance, 6);
        
        scenario::end(scenario);
    }
    
    #[test]
    fun test_comprehensive_calculation_functions() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Test APY reward calculations with various parameters
        let stake_amount = 10000u64; // 10k points staked
        let apy_bps = 500u64; // 5% APY
        let duration_seconds = 365 * 24 * 60 * 60; // 1 year
        let usd_precision = 1000u64;
        
        let calculated_rewards = ledger_v2::calculate_apy_rewards(
            stake_amount,
            apy_bps,
            duration_seconds,
            usd_precision
        );
        
        // Verify calculation worked
        assert!(calculated_rewards > 0, 1);
        
        // Test SUI to USD conversion
        let sui_amount = 1000000000u64; // 1 SUI (9 decimals)
        let sui_price_milli_usd = 2000u64; // $2.00 per SUI
        let usd_value = ledger_v2::convert_sui_to_usd_value(
            sui_amount,
            sui_price_milli_usd
        );
        
        // Verify conversion worked
        assert!(usd_value > 0, 2);
        
        scenario::end(scenario);
    }
    
    #[test]
    fun test_comprehensive_balance_functions() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup ledger
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::return_shared(config);
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Test ALL balance functions
        let available_balance = ledger_v2::get_available_balance(&ledger, USER1);
        let locked_balance = ledger_v2::get_locked_balance(&ledger, USER1);
        let total_balance = ledger_v2::get_total_balance(&ledger, USER1);
        
        assert!(available_balance == 0, 1);
        assert!(locked_balance == 0, 2);
        assert!(total_balance == 0, 3);
        
        // Test daily mint info
        let (daily_minted, daily_limit) = ledger_v2::get_daily_mint_info(&ledger, USER1, &clock);
        assert!(daily_minted == 0, 4);
        assert!(daily_limit > 0, 5);
        
        // Test supply functions
        let actual_supply = ledger_v2::get_actual_supply(&ledger);
        let total_minted = ledger_v2::get_total_minted(&ledger);
        let total_burned = ledger_v2::get_total_burned(&ledger);
        
        assert!(actual_supply == 0, 6);
        assert!(total_minted == 0, 7);
        assert!(total_burned == 0, 8);
        
        // Test ledger stats
        let (stats_minted, stats_burned, stats_supply, stats_global, stats_locked, stats_paused) = ledger_v2::get_ledger_stats(&ledger);
        assert!(stats_minted == 0, 9);
        assert!(stats_burned == 0, 10);
        assert!(stats_supply == 0, 11);
        assert!(stats_global == 1000000000000, 12); // max_total_supply
        assert!(stats_locked == 0, 13);
        assert!(!stats_paused, 14);
        
        // Test admin cap ID setting
        let admin_cap_id = admin_v2::get_admin_cap_uid_to_inner(&admin_cap);
        ledger_v2::set_admin_cap_id(&mut ledger, admin_cap_id);
        
        // Cleanup
        scenario::return_shared(ledger);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_comprehensive_lock_unlock_functions() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup ledger
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::return_shared(config);
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // First mint some points
        let mint_amount = 1000u64;
        ledger_v2::mint_points_for_testing(&mut ledger, USER1, mint_amount, scenario::ctx(&mut scenario));
        
        // Test lock points function
        let lock_amount = 500u64;
        ledger_v2::lock_points(
            &mut ledger,
            USER1,
            lock_amount,
            b"test_lock",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify locking worked
        let available_after_lock = ledger_v2::get_available_balance(&ledger, USER1);
        let locked_after_lock = ledger_v2::get_locked_balance(&ledger, USER1);
        let total_after_lock = ledger_v2::get_total_balance(&ledger, USER1);
        
        assert!(available_after_lock == mint_amount - lock_amount, 1);
        assert!(locked_after_lock == lock_amount, 2);
        assert!(total_after_lock == mint_amount, 3);
        
        // Test unlock points function
        let unlock_amount = 200u64;
        ledger_v2::unlock_points(
            &mut ledger,
            USER1,
            unlock_amount,
            b"test_unlock",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify unlocking worked
        let available_after_unlock = ledger_v2::get_available_balance(&ledger, USER1);
        let locked_after_unlock = ledger_v2::get_locked_balance(&ledger, USER1);
        let total_after_unlock = ledger_v2::get_total_balance(&ledger, USER1);
        
        assert!(available_after_unlock == mint_amount - lock_amount + unlock_amount, 4);
        assert!(locked_after_unlock == lock_amount - unlock_amount, 5);
        assert!(total_after_unlock == mint_amount, 6);
        
        // Cleanup
        scenario::return_shared(ledger);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_comprehensive_testing_functions() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup ledger
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::return_shared(config);
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Test mint_points_for_testing function
        let mint_amount = 1000u64;
        ledger_v2::mint_points_for_testing(&mut ledger, USER1, mint_amount, scenario::ctx(&mut scenario));
        
        // Test burn_points_for_testing function
        let burn_amount = 300u64;
        ledger_v2::burn_points_for_testing(&mut ledger, USER1, burn_amount, b"test_burn", &clock, scenario::ctx(&mut scenario));
        
        // Verify test functions worked
        let final_balance = ledger_v2::get_balance(&ledger, USER1);
        let total_minted = ledger_v2::get_total_minted(&ledger);
        let total_burned = ledger_v2::get_total_burned(&ledger);
        
        assert!(final_balance == mint_amount - burn_amount, 1);
        assert!(total_minted == mint_amount, 2);
        assert!(total_burned == burn_amount, 3);
        
        // Cleanup
        scenario::return_shared(ledger);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
} 