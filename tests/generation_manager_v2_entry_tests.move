#[test_only]
module alpha_points::generation_manager_v2_entry_tests {
    use std::string;
    use std::option;
    use std::vector;
    use sui::test_scenario::{Self as scenario};
    use sui::clock::{Self};
    use sui::transfer;
    use sui::object;
    use sui::test_utils;
    
    use alpha_points::admin_v2::{Self};
    use alpha_points::generation_manager_v2::{Self, IntegrationRegistry, PartnerIntegration, RegisteredAction};
    use alpha_points::partner_v3::{Self, PartnerCapV3, PartnerVault};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    const PARTNER1: address = @0xC;
    const PARTNER2: address = @0xD;
    const ACTION_NAME: vector<u8> = b"test_action";
    const DISPLAY_NAME: vector<u8> = b"Test Action";
    const DESCRIPTION: vector<u8> = b"Test action description";
    const CATEGORY: vector<u8> = b"gaming";
    const WEBHOOK_URL: vector<u8> = b"https://test.com/webhook";
    const CONTEXT_DATA: vector<u8> = b"test_context_data";
    const EXECUTION_SOURCE: vector<u8> = b"web_app";
    
    // =================== TEST 1: Registry Creation ===================
    
    #[test]
    fun test_create_integration_registry_v2() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create integration registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Verify registry was created successfully
        let registry_id = generation_manager_v2::get_registry_id(&registry);
        assert!(registry_id != object::id_from_address(@0x0), 1);
        
        // Verify initial stats
        let (total_integrations, total_actions, total_executions, total_points, active_integrations) = generation_manager_v2::get_registry_stats(&registry);
        assert!(total_integrations == 0, 2);
        assert!(total_actions == 0, 3);
        assert!(total_executions == 0, 4);
        assert!(total_points == 0, 5);
        assert!(active_integrations == 0, 6);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        transfer::public_transfer(admin_cap, @0x0);
        scenario::return_shared(registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 2: Partner Integration Registration ===================
    
    #[test]
    fun test_register_partner_integration() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create integration registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create partner registry and partner for testing
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let usdc_coin = partner_v3::create_test_usdc_coin(1000000000, scenario::ctx(&mut scenario)); // 1000 USDC
        
        // Switch to PARTNER1 before creating the vault
        scenario::next_tx(&mut scenario, PARTNER1);
        
        partner_v3::create_partner_with_usdc_vault(
            &mut partner_registry,
            &config,
            usdc_coin,
            string::utf8(b"Test Partner"),
            string::utf8(b"Test partner description"),
            1, // generation_id
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Get the partner objects
        scenario::next_tx(&mut scenario, PARTNER1);
        let partner_cap = scenario::take_from_sender<PartnerCapV3>(&scenario);
        let partner_vault = scenario::take_from_sender<PartnerVault>(&scenario);
        
        // Register partner integration
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Test Integration"),
            string::utf8(b"web_app"),
            option::some(string::utf8(b"https://test.com/webhook")),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify integration was registered
        let (total_integrations, _total_actions, _total_executions, _total_points, active_integrations) = generation_manager_v2::get_registry_stats(&registry);
        assert!(total_integrations == 1, 7);
        assert!(active_integrations == 1, 8);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        transfer::public_transfer(admin_cap, @0x0);
        transfer::public_transfer(partner_cap, @0x0);
        transfer::public_transfer(partner_vault, @0x0);
        scenario::return_shared(registry);
        test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 3: Action Registration ===================
    
    #[test]
    fun test_register_action() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create integration registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create partner registry and partner for testing
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let usdc_coin = partner_v3::create_test_usdc_coin(1000000000, scenario::ctx(&mut scenario)); // 1000 USDC
        
        // Switch to PARTNER1 before creating the vault
        scenario::next_tx(&mut scenario, PARTNER1);
        
        partner_v3::create_partner_with_usdc_vault(
            &mut partner_registry,
            &config,
            usdc_coin,
            string::utf8(b"Test Partner"),
            string::utf8(b"Test partner description"),
            1, // generation_id
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Get the partner objects
        scenario::next_tx(&mut scenario, PARTNER1);
        let partner_cap = scenario::take_from_sender<PartnerCapV3>(&scenario);
        let partner_vault = scenario::take_from_sender<PartnerVault>(&scenario);
        
        // Register partner integration first
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Test Integration"),
            string::utf8(b"web_app"),
            option::some(string::utf8(b"https://test.com/webhook")),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Get the integration object
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Register action
        generation_manager_v2::register_action(
            &mut registry,
            &mut integration,
            &partner_cap,
            string::utf8(ACTION_NAME),
            string::utf8(DISPLAY_NAME),
            string::utf8(DESCRIPTION),
            string::utf8(CATEGORY),
            100, // points_per_execution
            option::some(1000u64), // max_daily_executions
            5000u64, // cooldown_period_ms
            true, // requires_context_data
            option::some(string::utf8(WEBHOOK_URL)),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify action was registered
        let (_total_integrations, _total_actions, total_executions, total_points, _active_integrations) = generation_manager_v2::get_registry_stats(&registry);
        assert!(_total_integrations == 1, 9);
        assert!(_total_actions == 1, 10);
        assert!(total_executions == 0, 11);
        assert!(total_points == 0, 12);
        assert!(_active_integrations == 1, 13);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        transfer::public_transfer(admin_cap, @0x0);
        transfer::public_transfer(partner_cap, @0x0);
        transfer::public_transfer(partner_vault, @0x0);
        scenario::return_shared(integration);
        scenario::return_shared(registry);
        test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 4: Action Execution ===================
    
    #[test]
    fun test_execute_registered_action() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create ledger
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Create integration registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create partner registry and partner for testing
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let usdc_coin = partner_v3::create_test_usdc_coin(1000000000, scenario::ctx(&mut scenario)); // 1000 USDC
        
        // Switch to PARTNER1 before creating the vault
        scenario::next_tx(&mut scenario, PARTNER1);
        
        partner_v3::create_partner_with_usdc_vault(
            &mut partner_registry,
            &config,
            usdc_coin,
            string::utf8(b"Test Partner"),
            string::utf8(b"Test partner description"),
            1, // generation_id
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Get the partner objects
        scenario::next_tx(&mut scenario, PARTNER1);
        let partner_cap = scenario::take_from_sender<PartnerCapV3>(&scenario);
        let mut partner_vault = scenario::take_from_sender<PartnerVault>(&scenario);
        
        // Register partner integration first
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Test Integration"),
            string::utf8(b"web_app"),
            option::some(string::utf8(b"https://test.com/webhook")),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Get the integration object
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Register action
        generation_manager_v2::register_action(
            &mut registry,
            &mut integration,
            &partner_cap,
            string::utf8(ACTION_NAME),
            string::utf8(DISPLAY_NAME),
            string::utf8(DESCRIPTION),
            string::utf8(CATEGORY),
            100, // points_per_execution
            option::some(1000u64), // max_daily_executions
            1000u64, // cooldown_period_ms
            true, // requires_context_data
            option::some(string::utf8(WEBHOOK_URL)),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Get the action object
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut action = scenario::take_shared<RegisteredAction>(&scenario);
        
        // Execute action
        generation_manager_v2::execute_registered_action(
            &mut registry,
            &mut integration,
            &mut action,
            &partner_cap,
            &mut partner_vault,
            &mut ledger,
            USER1,
            CONTEXT_DATA,
            string::utf8(EXECUTION_SOURCE),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify execution
        let (total_integrations, total_actions, total_executions, total_points, active_integrations) = generation_manager_v2::get_registry_stats(&registry);
        assert!(total_integrations == 1, 14);
        assert!(total_actions == 1, 15);
        assert!(total_executions == 1, 16);
        assert!(total_points == 100, 17); // 100 points minted
        assert!(active_integrations == 1, 18);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        transfer::public_transfer(admin_cap, @0x0);
        transfer::public_transfer(partner_cap, @0x0);
        transfer::public_transfer(partner_vault, @0x0);
        scenario::return_shared(action);
        scenario::return_shared(integration);
        scenario::return_shared(ledger);
        scenario::return_shared(registry);
        test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 5: Multiple Action Executions ===================
    
    #[test]
    fun test_multiple_action_executions() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create ledger
        ledger_v2::create_ledger_for_testing_and_share(&admin_cap, &config, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut ledger = scenario::take_shared<LedgerV2>(&scenario);
        
        // Create integration registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create partner registry and partner for testing
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let usdc_coin = partner_v3::create_test_usdc_coin(1000000000, scenario::ctx(&mut scenario)); // 1000 USDC
        
        // Switch to PARTNER1 before creating the vault
        scenario::next_tx(&mut scenario, PARTNER1);
        
        partner_v3::create_partner_with_usdc_vault(
            &mut partner_registry,
            &config,
            usdc_coin,
            string::utf8(b"Test Partner"),
            string::utf8(b"Test partner description"),
            1, // generation_id
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Get the partner objects
        scenario::next_tx(&mut scenario, PARTNER1);
        let partner_cap = scenario::take_from_sender<PartnerCapV3>(&scenario);
        let mut partner_vault = scenario::take_from_sender<PartnerVault>(&scenario);
        
        // Register partner integration first
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Test Integration"),
            string::utf8(b"web_app"),
            option::some(string::utf8(b"https://test.com/webhook")),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Get the integration object
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Register action
        generation_manager_v2::register_action(
            &mut registry,
            &mut integration,
            &partner_cap,
            string::utf8(ACTION_NAME),
            string::utf8(DISPLAY_NAME),
            string::utf8(DESCRIPTION),
            string::utf8(CATEGORY),
            50, // points_per_execution
            option::some(10u64), // max_daily_executions
            1000u64, // cooldown_period_ms (minimum required)
            false, // requires_context_data
            option::none(), // no webhook
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Get the action object
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut action = scenario::take_shared<RegisteredAction>(&scenario);
        
        // Execute action multiple times for different users
        generation_manager_v2::execute_registered_action(
            &mut registry,
            &mut integration,
            &mut action,
            &partner_cap,
            &mut partner_vault,
            &mut ledger,
            USER1,
            vector::empty<u8>(), // No context data required
            string::utf8(EXECUTION_SOURCE),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        generation_manager_v2::execute_registered_action(
            &mut registry,
            &mut integration,
            &mut action,
            &partner_cap,
            &mut partner_vault,
            &mut ledger,
            USER1, // Same user, different execution
            vector::empty<u8>(),
            string::utf8(EXECUTION_SOURCE),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify multiple executions
        let (_total_integrations, _total_actions, total_executions, total_points, _active_integrations) = generation_manager_v2::get_registry_stats(&registry);
        assert!(total_executions == 2, 19);
        assert!(total_points == 100, 20); // 50 + 50 points
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        transfer::public_transfer(admin_cap, @0x0);
        transfer::public_transfer(partner_cap, @0x0);
        transfer::public_transfer(partner_vault, @0x0);
        scenario::return_shared(action);
        scenario::return_shared(integration);
        scenario::return_shared(ledger);
        scenario::return_shared(registry);
        test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 6: Admin Functions ===================
    
    #[test]
    fun test_emergency_pause_all_integrations() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create integration registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create integration cap for testing
        let integration_cap = 
            generation_manager_v2::create_test_integration_cap(
                generation_manager_v2::get_registry_id(&registry), 
                scenario::ctx(&mut scenario)
            );
        
        // Test emergency_pause_all_integrations function
        generation_manager_v2::emergency_pause_all_integrations(
            &mut registry,
            &integration_cap,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        transfer::public_transfer(admin_cap, @0x0);
        sui::test_utils::destroy(integration_cap);
        scenario::return_shared(registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_resume_all_integrations() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create integration registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create integration cap for testing
        let integration_cap = 
            generation_manager_v2::create_test_integration_cap(
                generation_manager_v2::get_registry_id(&registry), 
                scenario::ctx(&mut scenario)
            );
        
        // Test resume_all_integrations function
        generation_manager_v2::resume_all_integrations(
            &mut registry,
            &integration_cap,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        transfer::public_transfer(admin_cap, @0x0);
        sui::test_utils::destroy(integration_cap);
        scenario::return_shared(registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 7: Multiple Partners ===================
    
    #[test]
    fun test_multiple_partners() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup admin config with properly linked admin cap
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create integration registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create partner registry
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create first partner
        let usdc_coin1 = partner_v3::create_test_usdc_coin(1000000000, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, PARTNER1);
        
        partner_v3::create_partner_with_usdc_vault(
            &mut partner_registry,
            &config,
            usdc_coin1,
            string::utf8(b"Partner 1"),
            string::utf8(b"First partner description"),
            1,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let partner_cap1 = scenario::take_from_sender<PartnerCapV3>(&scenario);
        let partner_vault1 = scenario::take_from_sender<PartnerVault>(&scenario);
        
        // Register first partner integration
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap1,
            &partner_vault1,
            string::utf8(b"Integration 1"),
            string::utf8(b"web_app"),
            option::some(string::utf8(b"https://partner1.com/webhook")),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Create second partner
        let usdc_coin2 = partner_v3::create_test_usdc_coin(1000000000, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, PARTNER2);
        
        partner_v3::create_partner_with_usdc_vault(
            &mut partner_registry,
            &config,
            usdc_coin2,
            string::utf8(b"Partner 2"),
            string::utf8(b"Second partner description"),
            1,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER2);
        let partner_cap2 = scenario::take_from_sender<PartnerCapV3>(&scenario);
        let partner_vault2 = scenario::take_from_sender<PartnerVault>(&scenario);
        
        // Register second partner integration
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap2,
            &partner_vault2,
            string::utf8(b"Integration 2"),
            string::utf8(b"mobile_app"),
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify multiple integrations
        let (total_integrations, total_actions, total_executions, total_points, active_integrations) = generation_manager_v2::get_registry_stats(&registry);
        assert!(total_integrations == 2, 21);
        assert!(total_actions == 0, 22);
        assert!(total_executions == 0, 23);
        assert!(total_points == 0, 24);
        assert!(active_integrations == 2, 25);
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        transfer::public_transfer(admin_cap, @0x0);
        transfer::public_transfer(partner_cap1, @0x0);
        transfer::public_transfer(partner_vault1, @0x0);
        transfer::public_transfer(partner_cap2, @0x0);
        transfer::public_transfer(partner_vault2, @0x0);
        scenario::return_shared(registry);
        test_utils::destroy(partner_registry);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 8: Integration Cap Management ===================
    
    #[test]
    fun test_integration_cap_creation() {
        let mut scenario = scenario::begin(ADMIN);
        
        // Test integration cap creation with different registry IDs
        let registry_id1 = object::id_from_address(@0x111);
        let registry_id2 = object::id_from_address(@0x222);
        
        let cap1 = generation_manager_v2::create_test_integration_cap(registry_id1, scenario::ctx(&mut scenario));
        let cap2 = generation_manager_v2::create_test_integration_cap(registry_id2, scenario::ctx(&mut scenario));
        
        // Test that caps were created successfully (we can't access private fields)
        // Just verify the caps exist and can be destroyed
        sui::test_utils::destroy(cap1);
        sui::test_utils::destroy(cap2);
        
        // Clean up
        scenario::end(scenario);
    }
} 