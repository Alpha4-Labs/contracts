#[test_only]
module alpha_points::minimal_coverage_test {
    use sui::test_scenario::{Self as scenario};
    use sui::clock::{Self};
    
    use alpha_points::admin_v2::{Self, ConfigV2};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    
    #[test]
    fun test_minimal_admin_coverage() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin config - let the module handle sharing
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        // Test basic admin getter functions for coverage
        assert!(admin_v2::get_apy_basis_points(&config) == 500, 0);
        assert!(admin_v2::get_points_per_usd(&config) == 1000, 0);
        assert!(admin_v2::get_apy_percentage(&config) == 5, 0);  // 500 bps = 5%
        let _treasury = admin_v2::get_treasury_address();
        assert!(admin_v2::get_max_total_supply(&config) > 0, 0);
        assert!(admin_v2::get_daily_mint_cap_global(&config) > 0, 0);
        assert!(admin_v2::get_daily_mint_cap_per_user(&config) > 0, 0);
        
        // Test pause state functions
        assert!(admin_v2::is_paused(&config) == false, 0);
        let (is_paused, mint_paused, redemption_paused, governance_paused) = admin_v2::get_pause_states(&config);
        assert!(is_paused == false && mint_paused == false && redemption_paused == false && governance_paused == false, 0);
        
        // Test config info - with correct 5 return values
        let (apy_bps, points_per_usd, _max_supply, _daily_cap, is_paused_check) = admin_v2::get_config_info(&config);
        assert!(apy_bps == 500 && points_per_usd == 1000 && is_paused_check == false, 0);
        
        // Test assertion functions don't panic with valid admin
        admin_v2::assert_not_paused(&config);
        admin_v2::assert_mint_not_paused(&config);
        admin_v2::assert_redemption_not_paused(&config);
        
        // Cleanup
        scenario::return_shared(config);
        sui::transfer::public_transfer(admin_cap, ADMIN);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_minimal_ledger_coverage() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config and ledger
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Test ALL ledger getter functions for maximum coverage
        assert!(ledger_v2::get_total_minted(&ledger) == 0, 0);
        assert!(ledger_v2::get_total_burned(&ledger) == 0, 0);
        assert!(ledger_v2::get_balance(&ledger, USER1) == 0, 0);
        assert!(ledger_v2::get_available_balance(&ledger, USER1) == 0, 0);
        assert!(ledger_v2::get_locked_balance(&ledger, USER1) == 0, 0);
        assert!(ledger_v2::get_total_balance(&ledger, USER1) == 0, 0);
        assert!(ledger_v2::get_actual_supply(&ledger) == 0, 0);
        
        // Test ledger statistics - with correct 6 return values
        let (total_minted, total_burned, actual_supply, _global_daily, _total_locked, _paused) = ledger_v2::get_ledger_stats(&ledger);
        assert!(total_minted == 0 && total_burned == 0 && actual_supply == 0, 0);
        
        // Test ALL point type functions for coverage
        let _staking_type = ledger_v2::staking_reward_type();
        let _governance_type = ledger_v2::governance_reward_type();
        let _referral_type = ledger_v2::referral_bonus_type();
        let _liquidity_type = ledger_v2::liquidity_mining_type();
        let _loan_type = ledger_v2::loan_collateral_type();
        let _emergency_type = ledger_v2::emergency_mint_type();
        let _partner_type = ledger_v2::partner_reward_type();
        
        // Test minting points using TEST-ONLY function - CORRECT 4 parameters
        let mint_amount = 1000;
        ledger_v2::mint_points_for_testing(
            &mut ledger,
            USER1,
            mint_amount,
            scenario::ctx(&mut scenario)
        );
        
        // Verify minting worked and test more getters
        assert!(ledger_v2::get_balance(&ledger, USER1) == mint_amount, 0);
        assert!(ledger_v2::get_total_minted(&ledger) == mint_amount, 0);
        assert!(ledger_v2::get_available_balance(&ledger, USER1) == mint_amount, 0);
        assert!(ledger_v2::get_total_balance(&ledger, USER1) == mint_amount, 0);
        
        // Test daily mint info - with correct 2 return values and clock
        let (_daily_minted, _daily_limit) = ledger_v2::get_daily_mint_info(&ledger, USER1, &clock);
        
        // Cleanup
        scenario::return_shared(ledger);
        scenario::return_shared(config);
        sui::transfer::public_transfer(admin_cap, ADMIN);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}