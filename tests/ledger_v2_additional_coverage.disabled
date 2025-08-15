#[test_only]
module alpha_points::ledger_v2_additional_coverage {
    use sui::test_scenario::{Self as scenario};
    use sui::clock::{Self, Clock};
    use sui::test_utils;
    
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    const USER2: address = @0xC;
    
    // =================== MINT POINTS WITH CONTROLS TESTING ===================
    
    #[test]
    fun test_mint_points_with_controls() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup ledger
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Test mint with different point types
        let mint_amount = 1000u64;
        
        // Test staking reward minting
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            mint_amount,
            ledger_v2::new_staking_reward(),
            b"staking_reward_test",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test partner reward minting
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            mint_amount,
            ledger_v2::new_partner_reward(),
            b"partner_reward_test",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify balance
        let user1_balance = ledger_v2::get_balance(&ledger, USER1);
        assert!(user1_balance == mint_amount * 2, 1);
        
        // Cleanup
        scenario::return_shared(ledger);
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== BURN POINTS TESTING ===================
    
    #[test]
    fun test_burn_points() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup ledger
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // First mint some points
        let initial_amount = 5000u64;
        ledger_v2::mint_points_for_testing(&mut ledger, USER1, initial_amount, scenario::ctx(&mut scenario));
        
        // Test burn_points_for_testing function
        let burn_amount = 2000u64;
        ledger_v2::burn_points_for_testing(
            &mut ledger,
            USER1,
            burn_amount,
            b"burn_test",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify balance after burn
        let balance_after_burn = ledger_v2::get_balance(&ledger, USER1);
        assert!(balance_after_burn == initial_amount - burn_amount, 1);
        
        // Verify total burned
        let total_burned = ledger_v2::get_total_burned(&ledger);
        assert!(total_burned == burn_amount, 2);
        
        // Cleanup
        scenario::return_shared(ledger);
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== LOCK AND UNLOCK POINTS TESTING ===================
    
    #[test]
    fun test_lock_unlock_points() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup ledger
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // First mint some points
        let initial_amount = 10000u64;
        ledger_v2::mint_points_for_testing(&mut ledger, USER1, initial_amount, scenario::ctx(&mut scenario));
        
        // Test lock_points function
        let lock_amount = 3000u64;
        ledger_v2::lock_points(
            &mut ledger,
            USER1,
            lock_amount,
            b"lock_test",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify balances after lock
        let available_after_lock = ledger_v2::get_available_balance(&ledger, USER1);
        let locked_after_lock = ledger_v2::get_locked_balance(&ledger, USER1);
        let total_after_lock = ledger_v2::get_total_balance(&ledger, USER1);
        
        assert!(available_after_lock == initial_amount - lock_amount, 1);
        assert!(locked_after_lock == lock_amount, 2);
        assert!(total_after_lock == initial_amount, 3);
        
        // Test unlock_points function
        let unlock_amount = 1500u64;
        ledger_v2::unlock_points(
            &mut ledger,
            USER1,
            unlock_amount,
            b"unlock_test",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify balances after unlock
        let available_after_unlock = ledger_v2::get_available_balance(&ledger, USER1);
        let locked_after_unlock = ledger_v2::get_locked_balance(&ledger, USER1);
        
        assert!(available_after_unlock == initial_amount - lock_amount + unlock_amount, 4);
        assert!(locked_after_unlock == lock_amount - unlock_amount, 5);
        
        // Cleanup
        scenario::return_shared(ledger);
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== CALCULATION FUNCTIONS TESTING ===================
    
    #[test]
    fun test_calculate_apy_rewards() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Test APY calculations
        let stake_amount = 10000u64;
        let apy_bps = 500u64; // 5% APY
        let one_year_seconds = 365 * 24 * 60 * 60;
        let usd_precision = 1000u64;
        
        let rewards = ledger_v2::calculate_apy_rewards(
            stake_amount,
            apy_bps,
            one_year_seconds,
            usd_precision
        );
        
        assert!(rewards > 0, 1);
        
        scenario::end(scenario);
    }
    
    #[test]
    fun test_convert_sui_to_usd_value() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Test SUI to USD conversions
        let sui_amount = 1000000000u64; // 1 SUI (9 decimals)
        let sui_price = 2000u64; // $2.00 per SUI
        
        let usd_value = ledger_v2::convert_sui_to_usd_value(
            sui_amount,
            sui_price
        );
        
        assert!(usd_value > 0, 1);
        
        scenario::end(scenario);
    }
    
    // =================== POINT TYPE FUNCTIONS TESTING ===================
    
    #[test]
    fun test_all_point_type_functions() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Test all point type getter functions
        let staking_type = ledger_v2::staking_reward_type();
        let governance_type = ledger_v2::governance_reward_type();
        let referral_type = ledger_v2::referral_bonus_type();
        let liquidity_type = ledger_v2::liquidity_mining_type();
        let loan_type = ledger_v2::loan_collateral_type();
        let emergency_type = ledger_v2::emergency_mint_type();
        let partner_type = ledger_v2::partner_reward_type();
        
        // Test all new point type functions
        let new_staking = ledger_v2::new_staking_reward();
        let new_governance = ledger_v2::new_governance_reward();
        let new_referral = ledger_v2::new_referral_bonus();
        let new_liquidity = ledger_v2::new_liquidity_mining();
        let new_loan = ledger_v2::new_loan_collateral();
        let new_emergency = ledger_v2::new_emergency_mint();
        let new_partner = ledger_v2::new_partner_reward();
        
        // Verify consistency
        assert!(staking_type == new_staking, 1);
        assert!(governance_type == new_governance, 2);
        assert!(referral_type == new_referral, 3);
        assert!(liquidity_type == new_liquidity, 4);
        assert!(loan_type == new_loan, 5);
        assert!(emergency_type == new_emergency, 6);
        assert!(partner_type == new_partner, 7);
        
        scenario::end(scenario);
    }
    
    // =================== DAILY MINT LIMITS TESTING ===================
    
    #[test]
    fun test_daily_mint_limits() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup ledger
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Test daily mint info for new user
        let (daily_minted_initial, daily_limit) = ledger_v2::get_daily_mint_info(&ledger, USER1, &clock);
        assert!(daily_minted_initial == 0, 1);
        assert!(daily_limit > 0, 2);
        
        // Cleanup
        scenario::return_shared(ledger);
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== SET ADMIN CAP ID TESTING ===================
    
    #[test]
    fun test_set_admin_cap_id() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Setup ledger
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Create a new admin cap
        let new_admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        let new_admin_cap_id = admin_v2::get_admin_cap_uid_to_inner(&new_admin_cap);
        
        // Test set_admin_cap_id function
        ledger_v2::set_admin_cap_id(&mut ledger, new_admin_cap_id);
        
        // Cleanup
        scenario::return_shared(ledger);
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        sui::test_utils::destroy(new_admin_cap);
        scenario::end(scenario);
    }
    
    // =================== LEDGER STATS TESTING ===================
    
    #[test]
    fun test_ledger_stats_functions() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Setup ledger
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Test all stats functions
        let actual_supply = ledger_v2::get_actual_supply(&ledger);
        assert!(actual_supply == 0, 1);
        
        let total_minted = ledger_v2::get_total_minted(&ledger);
        assert!(total_minted == 0, 2);
        
        let total_burned = ledger_v2::get_total_burned(&ledger);
        assert!(total_burned == 0, 3);
        
        let total_supply = ledger_v2::get_total_supply(&ledger);
        assert!(total_supply == 0, 4);
        
        // Test ledger_stats getter (returns tuple)
        let (stats_minted, stats_burned, stats_supply, stats_global, stats_locked, stats_paused) = ledger_v2::get_ledger_stats(&ledger);
        assert!(stats_minted == 0, 5);
        assert!(stats_burned == 0, 6);
        assert!(stats_supply == 0, 7);
        assert!(stats_global > 0, 8); // max_total_supply
        assert!(stats_locked == 0, 9);
        assert!(!stats_paused, 10);
        
        // Test balance functions
        let balance = ledger_v2::get_balance(&ledger, USER1);
        assert!(balance == 0, 11);
        
        let balance_test = ledger_v2::get_balance_test(&ledger, USER1);
        assert!(balance_test == 0, 12);
        
        // Cleanup
        scenario::return_shared(ledger);
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        scenario::end(scenario);
    }
}
