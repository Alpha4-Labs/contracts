#[test_only]
module alpha_points::ledger_v2_entry_tests {
    use std::string;
    use std::option;
    use sui::test_scenario::{Self as scenario, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::object;
    use sui::tx_context;
    use sui::sui::SUI;
    use sui::test_utils;
    
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    const MINT_AMOUNT: u64 = 50000; // 50k points (within daily cap of 100k)
    
    #[test]
    fun test_mint_points_with_controls() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create ledger
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Test mint_points_with_controls function
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            MINT_AMOUNT,
            ledger_v2::new_staking_reward(),
            b"test_mint",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        transfer::public_transfer(admin_cap, @0x0);
        test_utils::destroy(ledger);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_burn_points_with_controls() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create ledger
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Mint points first
        ledger_v2::mint_points_with_controls(
            &mut ledger,
            USER1,
            MINT_AMOUNT,
            ledger_v2::new_staking_reward(),
            b"test_mint",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test burn_points_with_controls function
        ledger_v2::burn_points_with_controls(
            &mut ledger,
            USER1,
            MINT_AMOUNT / 2,
            b"test_burn",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        transfer::public_transfer(admin_cap, @0x0);
        test_utils::destroy(ledger);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_set_emergency_pause() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create ledger with the same admin cap - ensure proper linking
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Test set_emergency_pause function
        ledger_v2::set_emergency_pause(
            &mut ledger,
            &admin_cap,
            &config,
            true, // pause
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        test_utils::destroy(ledger);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_update_economic_parameters() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create ledger with the same admin cap - ensure proper linking
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Test update_economic_parameters function
        ledger_v2::update_economic_parameters(
            &mut ledger,
            &admin_cap,
            &config,
            option::some(2_000_000_000_000), // new_max_supply
            option::some(200_000), // new_daily_cap_per_user
            option::some(20000000), // new_max_per_mint
            option::some(600), // new_apy_basis_points
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        sui::test_utils::destroy(admin_cap);
        test_utils::destroy(ledger);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_get_ledger_stats() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config
        admin_v2::create_config_for_testing_and_share(scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let config = scenario::take_shared<ConfigV2>(&scenario);
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        // Create ledger
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Test get_ledger_stats function
        let (total_minted, total_burned, total_supply, emergency_pause, mint_pause, burn_pause) = ledger_v2::get_ledger_stats(&ledger);
        
        // Cleanup
        scenario::return_shared(config);
        transfer::public_transfer(admin_cap, @0x0);
        test_utils::destroy(ledger);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
} 