#[test_only]
module alpha_points::ledger_v2_tests {
    use sui::test_scenario::{Self as scenario};
    use sui::clock;
    
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    const USER2: address = @0xC;
    const USER3: address = @0xD;
    
    #[test]
    fun test_basic_ledger_creation() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Create config and ledger using working pattern
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::return_shared(config);
        scenario::next_tx(&mut scenario, ADMIN);
        
        let ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Verify ledger was created correctly
        assert!(ledger_v2::get_total_minted(&ledger) == 0, 1);
        assert!(ledger_v2::get_total_burned(&ledger) == 0, 2);
        
        scenario::return_shared(ledger);
        admin_v2::destroy_test_admin_cap(admin_cap);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_basic_points_minting() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Setup ledger
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::return_shared(config);
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Test minting
        let amount = 1000u64;
        ledger_v2::mint_points_for_testing(&mut ledger, USER1, amount, scenario::ctx(&mut scenario));
        
        // Verify minting worked
        assert!(ledger_v2::get_balance(&ledger, USER1) == amount, 1);
        assert!(ledger_v2::get_total_minted(&ledger) == amount, 2);
        
        scenario::return_shared(ledger);
        admin_v2::destroy_test_admin_cap(admin_cap);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_basic_points_burning() {
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
        let amount = 2000u64;
        ledger_v2::mint_points_for_testing(&mut ledger, USER1, amount, scenario::ctx(&mut scenario));
        
        // Then burn some points
        let burn_amount = 500u64;
        ledger_v2::burn_points_for_testing(&mut ledger, USER1, burn_amount, b"test_burn", &clock, scenario::ctx(&mut scenario));
        
        // Verify burning worked
        assert!(ledger_v2::get_balance(&ledger, USER1) == amount - burn_amount, 1);
        assert!(ledger_v2::get_total_burned(&ledger) == burn_amount, 2);
        
        scenario::return_shared(ledger);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_multiple_user_operations() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Setup ledger
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::return_shared(config);
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Test multiple users
        ledger_v2::mint_points_for_testing(&mut ledger, USER1, 1000, scenario::ctx(&mut scenario));
        ledger_v2::mint_points_for_testing(&mut ledger, USER2, 2000, scenario::ctx(&mut scenario));
        ledger_v2::mint_points_for_testing(&mut ledger, USER3, 1500, scenario::ctx(&mut scenario));
        
        // Verify all balances
        assert!(ledger_v2::get_balance(&ledger, USER1) == 1000, 1);
        assert!(ledger_v2::get_balance(&ledger, USER2) == 2000, 2);
        assert!(ledger_v2::get_balance(&ledger, USER3) == 1500, 3);
        assert!(ledger_v2::get_total_minted(&ledger) == 4500, 4);
        
        scenario::return_shared(ledger);
        admin_v2::destroy_test_admin_cap(admin_cap);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_stress_small_operations() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Setup ledger
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::return_shared(config);
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Many small operations
        let mut i = 0;
        let mut total_expected = 0;
        while (i < 20) {
            let amount = 50 + i;  // Variable amounts
            ledger_v2::mint_points_for_testing(&mut ledger, USER1, amount, scenario::ctx(&mut scenario));
            total_expected = total_expected + amount;
            i = i + 1;
        };
        
        assert!(ledger_v2::get_balance(&ledger, USER1) == total_expected, 1);
        assert!(ledger_v2::get_total_minted(&ledger) == total_expected, 2);
        
        scenario::return_shared(ledger);
        admin_v2::destroy_test_admin_cap(admin_cap);
        scenario::end(scenario);
    }

    // ===== HIGH-VALUE PRODUCTION FUNCTION TESTS =====
    // These target the 190-instruction and 108-instruction functions!
    
    #[test]
    fun test_production_mint_with_controls() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup ledger
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::return_shared(config);
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        let config = scenario::take_shared<ConfigV2>(&scenario);
        
        // Test PRODUCTION minting function with all controls
        let amount = 1000u64;
        let point_type = ledger_v2::partner_reward_type();
        let reason = b"partner_rewards";
        
        // This hits the HIGH-VALUE 190-instruction function!
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            amount,
            point_type,
            reason,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify minting worked with all controls
        assert!(ledger_v2::get_balance(&ledger, USER1) == amount, 1);
        assert!(ledger_v2::get_total_minted(&ledger) == amount, 2);
        
        scenario::return_shared(ledger);
        scenario::return_shared(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_production_burn_with_controls() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup ledger
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::return_shared(config);
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        let config = scenario::take_shared<ConfigV2>(&scenario);
        
        // First mint points using production function
        let mint_amount = 2000u64;
        let point_type = ledger_v2::partner_reward_type();
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            mint_amount,
            point_type,
            b"partner_rewards",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Then burn using PRODUCTION burning function with all controls
        let burn_amount = 500u64;
        
        // This hits the HIGH-VALUE 108-instruction function!
        ledger_v2::burn_points_with_controls(
            &mut ledger,
            USER1,
            burn_amount,
            b"perk_redemption",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify burning worked with all controls
        assert!(ledger_v2::get_balance(&ledger, USER1) == mint_amount - burn_amount, 1);
        assert!(ledger_v2::get_total_burned(&ledger) == burn_amount, 2);
        
        scenario::return_shared(ledger);
        scenario::return_shared(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_comprehensive_economic_calculations() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup ledger
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::return_shared(config);
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        let config = scenario::take_shared<ConfigV2>(&scenario);
        
        // Test comprehensive economic functions
        let stake_amount = 10000u64; // 10k points staked
        
        // Test APY reward calculations (86.11% coverage function)
        let calculated_rewards = ledger_v2::calculate_apy_rewards(
            stake_amount,          // principal_usd_value
            500,                   // apy_basis_points (5% APY)
            365 * 24 * 60 * 60,   // duration_seconds (1 year)
            1000                   // usd_precision
        );
        
        // Verify rewards calculation worked
        assert!(calculated_rewards > 0, 1);
        
        // Test multiple point types
        let staking_type = ledger_v2::staking_reward_type();
        let governance_type = ledger_v2::governance_reward_type();
        let referral_type = ledger_v2::referral_bonus_type();
        
        // Mint different types of points using production controls
        ledger_v2::mint_points_with_controls(
            &mut ledger, USER1, 1000, staking_type, b"staking_rewards", &clock, scenario::ctx(&mut scenario)
        );
        ledger_v2::mint_points_with_controls(
            &mut ledger, USER2, 500, governance_type, b"governance_participation", &clock, scenario::ctx(&mut scenario)
        );
        ledger_v2::mint_points_with_controls(
            &mut ledger, USER3, 750, referral_type, b"referral_bonus", &clock, scenario::ctx(&mut scenario)
        );
        
        // Verify comprehensive stats
        let total_minted = ledger_v2::get_total_minted(&ledger);
        assert!(total_minted == 2250, 2);
        
        // Get comprehensive ledger stats (100% coverage function)
        let (_supply, _burned, _locked, _available, _locked_global, _emergency_paused) = ledger_v2::get_ledger_stats(&ledger);
        
        scenario::return_shared(ledger);
        scenario::return_shared(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_advanced_daily_limits_and_quotas() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup ledger
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::return_shared(config);
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        let config = scenario::take_shared<ConfigV2>(&scenario);
        
        // Test daily mint info functionality (69.81% coverage function)
        let (daily_minted, _limit) = ledger_v2::get_daily_mint_info(&ledger, USER1, &clock);
        assert!(daily_minted == 0, 1); // Should start at 0
        
        // Test multiple mints throughout "day" to exercise daily limits
        let point_type = ledger_v2::partner_reward_type();
        
        // Mint several times to exercise daily limit logic in production function
        ledger_v2::mint_points_with_controls(
            &mut ledger, USER1, 100, point_type, b"batch_1", &clock, scenario::ctx(&mut scenario)
        );
        ledger_v2::mint_points_with_controls(
            &mut ledger, USER1, 200, point_type, b"batch_2", &clock, scenario::ctx(&mut scenario)
        );
        ledger_v2::mint_points_with_controls(
            &mut ledger, USER1, 150, point_type, b"batch_3", &clock, scenario::ctx(&mut scenario)
        );
        
        // Verify accumulated balance
        assert!(ledger_v2::get_balance(&ledger, USER1) == 450, 2);
        
        // Test available vs locked balance functions
        let available = ledger_v2::get_available_balance(&ledger, USER1);
        let locked = ledger_v2::get_locked_balance(&ledger, USER1); // 58.82% coverage
        let total = ledger_v2::get_total_balance(&ledger, USER1);
        
        assert!(available + locked == total, 3);
        
        scenario::return_shared(ledger);
        scenario::return_shared(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
} 