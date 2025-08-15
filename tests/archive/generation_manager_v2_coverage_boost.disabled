#[test_only]
module alpha_points::generation_manager_v2_coverage_boost {
    use sui::test_scenario::{Self as scenario};
    use sui::clock::{Self, Clock};
    use std::string::{Self, String};
    use std::option;
    
    // Import all required modules
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::generation_manager_v2::{Self, IntegrationRegistry, PartnerIntegration, RegisteredAction};
    use alpha_points::partner_v3::{Self, PartnerCapV3, PartnerVault};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    
    // Test addresses
    const ADMIN: address = @0xAD;
    const PARTNER1: address = @0x333;
    const USER1: address = @0x111;
    const USER2: address = @0x222;
    
    // Test constants
    const USDC_AMOUNT: u64 = 10000_000_000; // 10,000 USDC
    const POINTS_PER_ACTION: u64 = 100; // 100 points per action
    
    // =================== TEST 1: Core Action Execution ===================
    
    #[test]
    fun test_execute_registered_action_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup complete infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create integration registry
        let mut registry = generation_manager_v2::create_integration_registry_for_testing(
            &config, &admin_cap, &clock, scenario::ctx(&mut scenario)
        );
        
        // Create partner with vault
        let (partner_cap, mut partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER1,
            USDC_AMOUNT,
            100000, // 100K daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // Register partner integration
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Gaming App Integration"),
            string::utf8(b"mobile_app"),
            option::some(string::utf8(b"https://api.gameapp.com/webhook")),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Get the integration object
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Register an action
        generation_manager_v2::register_action(
            &mut registry,
            &mut integration,
            &partner_cap,
            string::utf8(b"level_completed"),
            string::utf8(b"Level Completed"),
            string::utf8(b"Player completed a game level"),
            string::utf8(b"gaming"),
            POINTS_PER_ACTION,
            option::some(1000), // 1000 daily limit
            1000, // 1 second cooldown
            true, // requires context data
            option::some(string::utf8(b"https://api.gameapp.com/level-webhook")),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Get the action object
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut action = scenario::take_shared<RegisteredAction>(&scenario);
        
        // Test successful action execution
        let context_data = b"level_5_boss_defeated";
        generation_manager_v2::execute_registered_action(
            &mut registry,
            &mut integration,
            &mut action,
            &partner_cap,
            &mut partner_vault,
            &mut ledger,
            USER1,
            context_data,
            string::utf8(b"mobile_app"),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify action execution statistics
        let (_, _, _, _, total_executions, _) = generation_manager_v2::get_action_info(&action);
        assert!(total_executions == 1, 1);
        
        // Test multiple executions by different users
        generation_manager_v2::execute_registered_action(
            &mut registry,
            &mut integration,
            &mut action,
            &partner_cap,
            &mut partner_vault,
            &mut ledger,
            USER2,
            b"level_3_completed",
            string::utf8(b"web_app"),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        let (_, _, _, _, total_executions_2, _) = generation_manager_v2::get_action_info(&action);
        assert!(total_executions_2 == 2, 2);
        
        // Test integration statistics
        let (total_requests, monthly_executions, monthly_points, unique_users, health_score) = 
            generation_manager_v2::get_integration_stats(&integration);
        assert!(total_requests >= 2, 3);
        assert!(monthly_executions == 2, 4);
        assert!(monthly_points == POINTS_PER_ACTION * 2, 5);
        assert!(health_score > 0, 6);
        
        // Test registry statistics
        let (total_integrations, total_actions, total_executions, total_points, active_integrations) = 
            generation_manager_v2::get_registry_stats(&registry);
        assert!(total_integrations >= 1, 7);
        assert!(total_actions >= 1, 8);
        assert!(total_executions >= 2, 9);
        assert!(total_points >= POINTS_PER_ACTION * 2, 10);
        assert!(active_integrations >= 1, 11);
        
        // Cleanup
        scenario::return_shared(action);
        scenario::return_shared(integration);
        partner_v3::destroy_test_vault(partner_vault);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_registry);
        sui::test_utils::destroy(registry);
        sui::test_utils::destroy(ledger);
        admin_v2::destroy_config_for_testing(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 2: Rate Limiting and Execution Validation ===================
    
    #[test]
    fun test_rate_limiting_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        let mut registry = generation_manager_v2::create_integration_registry_for_testing(
            &config, &admin_cap, &clock, scenario::ctx(&mut scenario)
        );
        
        // Create partner with vault
        let (partner_cap, mut partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER1,
            USDC_AMOUNT,
            100000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // Register integration
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Rate Limit Test App"),
            string::utf8(b"api"),
            option::none(), // No webhook
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Register action with low daily limit
        generation_manager_v2::register_action(
            &mut registry,
            &mut integration,
            &partner_cap,
            string::utf8(b"limited_action"),
            string::utf8(b"Limited Action"),
            string::utf8(b"Action with low daily limit"),
            string::utf8(b"testing"),
            POINTS_PER_ACTION,
            option::some(3), // Only 3 executions per day
            1000, // 1 second cooldown (meets minimum requirement)
            false, // No context data required
            option::none(), // No webhook
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut action = scenario::take_shared<RegisteredAction>(&scenario);
        
        // Test can execute initially
        let can_execute_1 = generation_manager_v2::can_execute_action(&integration, &action, clock::timestamp_ms(&clock));
        assert!(can_execute_1, 1);
        
        // Execute action 3 times (daily limit)
        let mut i = 0;
        while (i < 3) {
            generation_manager_v2::execute_registered_action(
                &mut registry,
                &mut integration,
                &mut action,
                &partner_cap,
                &mut partner_vault,
                &mut ledger,
                USER1,
                b"",
                string::utf8(b"api"),
                &clock,
                scenario::ctx(&mut scenario)
            );
            i = i + 1;
        };
        
        // Test cannot execute after hitting daily limit
        let can_execute_2 = generation_manager_v2::can_execute_action(&integration, &action, clock::timestamp_ms(&clock));
        assert!(!can_execute_2, 2); // Should be false due to daily limit
        
        // Test daily reset by advancing time
        clock::increment_for_testing(&mut clock, 86400001); // 24+ hours
        
        // Execute one more to verify daily reset worked
        generation_manager_v2::execute_registered_action(
            &mut registry,
            &mut integration,
            &mut action,
            &partner_cap,
            &mut partner_vault,
            &mut ledger,
            USER1,
            b"",
            string::utf8(b"api"),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify execution count increased (proving daily reset worked)
        let (_, _, _, _, final_executions, _) = generation_manager_v2::get_action_info(&action);
        assert!(final_executions == 4, 3); // 3 + 1 after reset
        
        // Cleanup
        scenario::return_shared(action);
        scenario::return_shared(integration);
        partner_v3::destroy_test_vault(partner_vault);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_registry);
        sui::test_utils::destroy(registry);
        sui::test_utils::destroy(ledger);
        admin_v2::destroy_config_for_testing(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 3: Utility and View Functions ===================
    
    #[test]
    fun test_utility_functions_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        let mut registry = generation_manager_v2::create_integration_registry_for_testing(
            &config, &admin_cap, &clock, scenario::ctx(&mut scenario)
        );
        
        // Create partner with vault
        let (partner_cap, mut partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry,
            PARTNER1,
            USDC_AMOUNT,
            100000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // Register integration with webhook
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Utility Test Integration"),
            string::utf8(b"api"),
            option::some(string::utf8(b"https://api.utilitytest.com/webhook")),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Test integration info
        let (name, int_type, is_active, is_approved, action_count) = 
            generation_manager_v2::get_integration_info(&integration);
        assert!(name == string::utf8(b"Utility Test Integration"), 1);
        assert!(int_type == string::utf8(b"api"), 2);
        assert!(is_active, 3);
        assert!(action_count == 0, 4); // No actions yet
        
        // Register action to test utility functions
        generation_manager_v2::register_action(
            &mut registry,
            &mut integration,
            &partner_cap,
            string::utf8(b"utility_test_action"),
            string::utf8(b"Utility Test Action"),
            string::utf8(b"Action for testing utility functions"),
            string::utf8(b"testing"),
            POINTS_PER_ACTION,
            option::some(100),
            1000,
            true,
            option::some(string::utf8(b"https://action.webhook.com")),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut action = scenario::take_shared<RegisteredAction>(&scenario);
        
        // Test action info
        let (action_name, display_name, category, points_per_exec, total_execs, is_action_active) = 
            generation_manager_v2::get_action_info(&action);
        assert!(action_name == string::utf8(b"utility_test_action"), 5);
        assert!(points_per_exec == POINTS_PER_ACTION, 6);
        assert!(total_execs == 0, 7);
        assert!(is_action_active, 8);
        
        // Test multiple executions to trigger utility functions
        let mut execution_count = 0;
        while (execution_count < 5) {
            // Test with different users and context data
            let user = if (execution_count % 2 == 0) { USER1 } else { USER2 };
            let context = if (execution_count % 3 == 0) { 
                b"special_context_data" 
            } else { 
                b"normal_context" 
            };
            
            generation_manager_v2::execute_registered_action(
                &mut registry,
                &mut integration,
                &mut action,
                &partner_cap,
                &mut partner_vault,
                &mut ledger,
                user,
                context,
                string::utf8(b"api"),
                &clock,
                scenario::ctx(&mut scenario)
            );
            
            execution_count = execution_count + 1;
            
            // Small time increment
            clock::increment_for_testing(&mut clock, 1100); // 1.1 seconds (respect cooldown)
        };
        
        // Test final statistics
        let (_, _, _, _, total_executions, is_active) = generation_manager_v2::get_action_info(&action);
        assert!(total_executions == 5, 9);
        assert!(is_active, 10);
        
        let (total_requests, monthly_executions, monthly_points, unique_users, health_score) = 
            generation_manager_v2::get_integration_stats(&integration);
        assert!(total_requests >= 5, 11);
        assert!(monthly_executions == 5, 12);
        assert!(monthly_points == POINTS_PER_ACTION * 5, 13);
        assert!(health_score > 0, 14);
        
        // Test registry statistics after comprehensive usage
        let (total_integrations, total_actions, total_executions, total_points, active_integrations) = 
            generation_manager_v2::get_registry_stats(&registry);
        assert!(total_integrations >= 1, 15);
        assert!(total_actions >= 1, 16);
        assert!(total_executions >= 5, 17);
        assert!(total_points >= POINTS_PER_ACTION * 5, 18);
        assert!(active_integrations >= 1, 19);
        
        // Test get partner actions (placeholder function)
        let partner_actions = generation_manager_v2::get_partner_actions(&integration);
        // This returns empty vector in the current implementation, but tests the function
        
        // Test registry ID function
        let registry_id = generation_manager_v2::get_registry_id(&registry);
        // Should return a valid ID without crashing
        
        // Cleanup
        scenario::return_shared(action);
        scenario::return_shared(integration);
        partner_v3::destroy_test_vault(partner_vault);
        sui::test_utils::destroy(partner_cap);
        sui::test_utils::destroy(partner_registry);
        sui::test_utils::destroy(registry);
        sui::test_utils::destroy(ledger);
        admin_v2::destroy_config_for_testing(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}
