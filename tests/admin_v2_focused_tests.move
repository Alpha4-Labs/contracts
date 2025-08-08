#[test_only]
module alpha_points::admin_v2_focused_tests {
    use sui::test_scenario::{Self as scenario};
    use sui::clock;
    use sui::transfer;
    use std::option;
    
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    
    #[test]
    fun test_production_apy_rate_update() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin infrastructure - config_for_testing_and_share creates both config and admin cap
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, ADMIN);
        let mut config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = scenario::take_from_sender<AdminCapV2>(&scenario);
        
        // Test production APY update function (high-instruction count)
        let initial_apy = admin_v2::get_apy_basis_points(&config);
        let new_apy = 600; // Change from 500 to 600 basis points (5% to 6%)
        
        admin_v2::update_apy_rate(
            &mut config,
            &admin_cap,
            new_apy,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify the update worked
        let updated_apy = admin_v2::get_apy_basis_points(&config);
        assert!(updated_apy == new_apy, 1);
        
        scenario::return_shared(config);
        transfer::public_transfer(admin_cap, @0x0);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_production_grace_period_update() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin infrastructure
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, ADMIN);
        let mut config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = scenario::take_from_sender<AdminCapV2>(&scenario);
        
        // Test production grace period update function (high-instruction count)
        let new_grace_period = 3024000000; // 35 days in milliseconds (within change limit)
        
        admin_v2::update_grace_period(
            &mut config,
            &admin_cap,
            new_grace_period,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify update through getter
        let (_, _, _, grace_period, _) = admin_v2::get_config_info(&config);
        assert!(grace_period == new_grace_period, 2);
        
        scenario::return_shared(config);
        transfer::public_transfer(admin_cap, @0x0);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_production_economic_limits_update() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin infrastructure  
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, ADMIN);
        let mut config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = scenario::take_from_sender<AdminCapV2>(&scenario);
        
        // Test production economic limits update function (high-instruction count)
        let new_max_supply = option::some(2_000_000_000_000u64); // 2T points
        let new_daily_cap_global = option::some(200_000_000u64); // 200M daily
        let new_daily_cap_per_user = option::some(50_000u64); // 50K per user
        
        admin_v2::update_economic_limits(
            &mut config,
            &admin_cap,
            new_max_supply,
            new_daily_cap_global,
            new_daily_cap_per_user,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify updates through getters
        let max_supply = admin_v2::get_max_total_supply(&config);
        let daily_global = admin_v2::get_daily_mint_cap_global(&config);
        let daily_user = admin_v2::get_daily_mint_cap_per_user(&config);
        
        assert!(max_supply == 2_000_000_000_000u64, 3);
        assert!(daily_global == 200_000_000u64, 4);
        assert!(daily_user == 50_000u64, 5);
        
        scenario::return_shared(config);
        transfer::public_transfer(admin_cap, @0x0);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_production_emergency_pause_controls() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create admin infrastructure
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, ADMIN);
        let mut config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = scenario::take_from_sender<AdminCapV2>(&scenario);
        
        // Test emergency pause function (high-instruction count)
        assert!(!admin_v2::is_emergency_paused(&config), 6);
        
        // Activate emergency pause
        admin_v2::set_emergency_pause(
            &mut config,
            &admin_cap,
            1, // emergency pause type
            true, // activate pause
            b"Testing emergency pause functionality",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify pause is active
        assert!(admin_v2::is_emergency_paused(&config), 7);
        
        // Test mint pause
        admin_v2::set_emergency_pause(
            &mut config,
            &admin_cap,
            2, // mint pause type
            true, // activate pause
            b"Testing mint pause functionality",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify pause states
        let (is_emergency, is_mint, is_redemption, is_governance) = admin_v2::get_pause_states(&config);
        assert!(is_emergency, 8);
        assert!(is_mint, 9);
        assert!(!is_redemption, 10);
        assert!(!is_governance, 11);
        
        scenario::return_shared(config);
        transfer::public_transfer(admin_cap, @0x0);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_admin_authorization_validation() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Create admin infrastructure
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, ADMIN);
        let config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = scenario::take_from_sender<AdminCapV2>(&scenario);
        
        // Test authorization functions (production logic)
        let is_admin_authorized = admin_v2::is_admin(&admin_cap, &config);
        assert!(is_admin_authorized, 12);
        
        // Test admin cap ID functions
        let admin_cap_id = admin_v2::get_admin_cap_uid_to_inner(&admin_cap);
        let config_admin_id = admin_v2::admin_cap_id(&config);
        assert!(admin_cap_id == config_admin_id, 13);
        
        // Test pause assertion functions (production logic)
        admin_v2::assert_not_paused(&config);
        admin_v2::assert_mint_not_paused(&config);
        admin_v2::assert_redemption_not_paused(&config);
        
        scenario::return_shared(config);
        transfer::public_transfer(admin_cap, @0x0);
        scenario::end(scenario);
    }
} 