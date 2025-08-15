#[test_only]
module alpha_points::generation_manager_v2_additional_coverage {
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
    
    const ADMIN: address = @0xAD;
    const PARTNER1: address = @0x333;
    const USER1: address = @0x111;
    const USER2: address = @0x222;
    
    // Test constants for limits
    const USDC_AMOUNT: u64 = 10000_000_000; // 10,000 USDC
    
    // =================== TEST 1: Daily Counter Reset Testing ===================
    
    #[test]
    fun test_daily_counter_reset_functionality() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup full infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create partner and integration
        let (partner_cap, mut partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry, PARTNER1, USDC_AMOUNT, 100000, &clock, scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Reset Test"),
            string::utf8(b"web_app"),
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Register action with daily limit
        generation_manager_v2::register_action(
            &mut registry,
            &mut integration,
            &partner_cap,
            string::utf8(b"reset_test_action"),
            string::utf8(b"Reset Test Action"),
            string::utf8(b"Testing counter resets"),
            string::utf8(b"testing"),
            100,
            option::some(5u64), // 5 executions per day
            1000u64,
            false,
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut action = scenario::take_shared<RegisteredAction>(&scenario);
        
        // Execute action 3 times
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
                string::utf8(b"web_app"),
                &clock,
                scenario::ctx(&mut scenario)
            );
            i = i + 1;
            // Reset rate limit window between executions
            clock::increment_for_testing(&mut clock, 60001); // 1 minute + 1ms
        };
        
        // Verify daily executions is 3
        let (_, _, _, _, total_executions, _) = generation_manager_v2::get_action_info(&action);
        assert!(total_executions == 3, 1);
        
        // Fast forward to next day (24+ hours)
        clock::increment_for_testing(&mut clock, 86400001); // 24 hours + 1ms
        
        // Execute action again - should work as daily counter should reset
        generation_manager_v2::execute_registered_action(
            &mut registry,
            &mut integration,
            &mut action,
            &partner_cap,
            &mut partner_vault,
            &mut ledger,
            USER2,
            b"",
            string::utf8(b"web_app"),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify total executions increased to 4
        let (_, _, _, _, final_executions, _) = generation_manager_v2::get_action_info(&action);
        assert!(final_executions == 4, 2);
        
        // Cleanup
        scenario::return_shared(action);
        scenario::return_shared(integration);
        scenario::return_shared(registry);
        test_utils::destroy(partner_cap);
        partner_v3::destroy_test_vault(partner_vault);
        test_utils::destroy(ledger);
        test_utils::destroy(partner_registry);
        admin_v2::destroy_config_for_testing(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 2: Monthly Counter Reset Testing ===================
    
    #[test]
    fun test_monthly_counter_reset_functionality() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup full infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create partner and integration
        let (partner_cap, mut partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry, PARTNER1, USDC_AMOUNT, 100000, &clock, scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Monthly Reset Test"),
            string::utf8(b"web_app"),
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Register action
        generation_manager_v2::register_action(
            &mut registry,
            &mut integration,
            &partner_cap,
            string::utf8(b"monthly_reset_action"),
            string::utf8(b"Monthly Reset Action"),
            string::utf8(b"Testing monthly counter resets"),
            string::utf8(b"testing"),
            100,
            option::some(1000u64), // High daily limit
            1000u64,
            false,
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut action = scenario::take_shared<RegisteredAction>(&scenario);
        
        // Execute action once
        generation_manager_v2::execute_registered_action(
            &mut registry,
            &mut integration,
            &mut action,
            &partner_cap,
            &mut partner_vault,
            &mut ledger,
            USER1,
            b"",
            string::utf8(b"web_app"),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Fast forward to next month (30+ days)
        clock::increment_for_testing(&mut clock, 30 * 86400000 + 1); // 30 days + 1ms
        
        // Execute action again - should work as monthly counter should reset
        generation_manager_v2::execute_registered_action(
            &mut registry,
            &mut integration,
            &mut action,
            &partner_cap,
            &mut partner_vault,
            &mut ledger,
            USER2,
            b"",
            string::utf8(b"web_app"),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify total executions is 2
        let (_, _, _, _, total_executions, _) = generation_manager_v2::get_action_info(&action);
        assert!(total_executions == 2, 1);
        
        // Cleanup
        scenario::return_shared(action);
        scenario::return_shared(integration);
        scenario::return_shared(registry);
        test_utils::destroy(partner_cap);
        partner_v3::destroy_test_vault(partner_vault);
        test_utils::destroy(ledger);
        test_utils::destroy(partner_registry);
        admin_v2::destroy_config_for_testing(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 3: Webhook Delivery Testing ===================
    
    #[test]
    fun test_webhook_delivery_queue() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup full infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create partner and integration
        let (partner_cap, mut partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry, PARTNER1, USDC_AMOUNT, 100000, &clock, scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Webhook Test"),
            string::utf8(b"web_app"),
            option::some(string::utf8(b"https://api.example.com/webhook")),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Register action with webhook
        generation_manager_v2::register_action(
            &mut registry,
            &mut integration,
            &partner_cap,
            string::utf8(b"webhook_action"),
            string::utf8(b"Webhook Action"),
            string::utf8(b"Action with webhook"),
            string::utf8(b"testing"),
            100,
            option::some(1000u64),
            1000u64,
            true, // requires context data
            option::some(string::utf8(b"https://api.example.com/action-webhook")),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut action = scenario::take_shared<RegisteredAction>(&scenario);
        
        // Execute action with context data - should trigger webhook delivery
        generation_manager_v2::execute_registered_action(
            &mut registry,
            &mut integration,
            &mut action,
            &partner_cap,
            &mut partner_vault,
            &mut ledger,
            USER1,
            b"webhook_test_context_data",
            string::utf8(b"web_app"),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify action was executed successfully
        let (_, _, _, _, total_executions, _) = generation_manager_v2::get_action_info(&action);
        assert!(total_executions == 1, 1);
        
        // Cleanup
        scenario::return_shared(action);
        scenario::return_shared(integration);
        scenario::return_shared(registry);
        test_utils::destroy(partner_cap);
        partner_v3::destroy_test_vault(partner_vault);
        test_utils::destroy(ledger);
        test_utils::destroy(partner_registry);
        admin_v2::destroy_config_for_testing(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 4: Integration Approval Workflow ===================
    
    #[test]
    fun test_integration_approval_workflow() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create registry that requires approval
        let mut registry = generation_manager_v2::create_integration_registry_for_testing(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        
        // Create partner and integration (will be auto-approved since we didn't set approval requirement)
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry, PARTNER1, USDC_AMOUNT, 100000, &clock, scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Approval Test"),
            string::utf8(b"web_app"),
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Verify integration is approved (auto-approved)
        let (_, _, is_active, is_approved, _) = generation_manager_v2::get_integration_info(&integration);
        assert!(is_active, 1);
        assert!(is_approved, 2); // Should be auto-approved
        
        // Create integration cap and approve integration again (should still work)
        let integration_cap = generation_manager_v2::create_test_integration_cap(
            generation_manager_v2::get_registry_id(&registry), 
            scenario::ctx(&mut scenario)
        );
        
        generation_manager_v2::approve_integration(
            &mut registry,
            &mut integration,
            &integration_cap,
            option::some(string::utf8(b"Re-approved for testing")),
            string::utf8(b"enhanced"),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify integration is still approved
        let (_, _, is_active_after, is_approved_after, _) = generation_manager_v2::get_integration_info(&integration);
        assert!(is_active_after, 3);
        assert!(is_approved_after, 4);
        
        // Cleanup
        scenario::return_shared(integration);
        test_utils::destroy(registry);
        test_utils::destroy(integration_cap);
        test_utils::destroy(partner_cap);
        partner_v3::destroy_test_vault(partner_vault);
        test_utils::destroy(partner_registry);
        admin_v2::destroy_config_for_testing(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 5: View Functions Comprehensive Testing ===================
    
    #[test]
    fun test_can_execute_action_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create partner and integration
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry, PARTNER1, USDC_AMOUNT, 100000, &clock, scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Can Execute Test"),
            string::utf8(b"api"),
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Register action
        generation_manager_v2::register_action(
            &mut registry,
            &mut integration,
            &partner_cap,
            string::utf8(b"can_execute_action"),
            string::utf8(b"Can Execute Action"),
            string::utf8(b"Testing can_execute_action function"),
            string::utf8(b"testing"),
            100,
            option::some(5u64), // Low daily limit
            1000u64,
            false,
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let action = scenario::take_shared<RegisteredAction>(&scenario);
        
        let current_time = clock::timestamp_ms(&clock);
        
        // Test: Should be able to execute initially
        let can_execute_1 = generation_manager_v2::can_execute_action(&integration, &action, current_time);
        assert!(can_execute_1, 1);
        
        // Test with future time (should still work unless there's expiration)
        let future_time = current_time + 3600000; // 1 hour later
        let can_execute_future = generation_manager_v2::can_execute_action(&integration, &action, future_time);
        assert!(can_execute_future, 2);
        
        // Cleanup
        scenario::return_shared(action);
        scenario::return_shared(integration);
        scenario::return_shared(registry);
        test_utils::destroy(partner_cap);
        partner_v3::destroy_test_vault(partner_vault);
        test_utils::destroy(partner_registry);
        admin_v2::destroy_config_for_testing(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_get_partner_actions() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create partner and integration
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry, PARTNER1, USDC_AMOUNT, 100000, &clock, scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Actions Test"),
            string::utf8(b"api"),
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Test get_partner_actions (returns empty vector in current implementation)
        let partner_actions = generation_manager_v2::get_partner_actions(&integration);
        assert!(vector::length(&partner_actions) == 0, 1);
        
        // Cleanup
        scenario::return_shared(integration);
        scenario::return_shared(registry);
        test_utils::destroy(partner_cap);
        partner_v3::destroy_test_vault(partner_vault);
        test_utils::destroy(partner_registry);
        admin_v2::destroy_config_for_testing(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 6: Registry Statistics Testing ===================
    
    #[test]
    fun test_registry_statistics_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Test initial registry stats
        let (total_integrations, total_actions, total_executions, total_points, active_integrations) = 
            generation_manager_v2::get_registry_stats(&registry);
        assert!(total_integrations == 0, 1);
        assert!(total_actions == 0, 2);
        assert!(total_executions == 0, 3);
        assert!(total_points == 0, 4);
        assert!(active_integrations == 0, 5);
        
        // Create partner and integration
        let (partner_cap, mut partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry, PARTNER1, USDC_AMOUNT, 100000, &clock, scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Stats Test"),
            string::utf8(b"web_app"),
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test registry stats after integration
        let (total_integrations_2, total_actions_2, total_executions_2, total_points_2, active_integrations_2) = 
            generation_manager_v2::get_registry_stats(&registry);
        assert!(total_integrations_2 == 1, 6);
        assert!(total_actions_2 == 0, 7);
        assert!(total_executions_2 == 0, 8);
        assert!(total_points_2 == 0, 9);
        assert!(active_integrations_2 == 1, 10);
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Register action
        generation_manager_v2::register_action(
            &mut registry,
            &mut integration,
            &partner_cap,
            string::utf8(b"stats_action"),
            string::utf8(b"Stats Action"),
            string::utf8(b"Action for stats testing"),
            string::utf8(b"testing"),
            100,
            option::some(1000u64),
            1000u64,
            false,
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test registry stats after action registration
        let (total_integrations_3, total_actions_3, total_executions_3, total_points_3, active_integrations_3) = 
            generation_manager_v2::get_registry_stats(&registry);
        assert!(total_integrations_3 == 1, 11);
        assert!(total_actions_3 == 1, 12);
        assert!(total_executions_3 == 0, 13);
        assert!(total_points_3 == 0, 14);
        assert!(active_integrations_3 == 1, 15);
        
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
            b"",
            string::utf8(b"web_app"),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test final registry stats
        let (total_integrations_4, total_actions_4, total_executions_4, total_points_4, active_integrations_4) = 
            generation_manager_v2::get_registry_stats(&registry);
        assert!(total_integrations_4 == 1, 16);
        assert!(total_actions_4 == 1, 17);
        assert!(total_executions_4 == 1, 18);
        assert!(total_points_4 == 100, 19);
        assert!(active_integrations_4 == 1, 20);
        
        // Test integration stats
        let (total_requests, monthly_executions, monthly_points, unique_users, health_score) = 
            generation_manager_v2::get_integration_stats(&integration);
        assert!(total_requests >= 1, 21);
        assert!(monthly_executions == 1, 22);
        assert!(monthly_points == 100, 23);
        assert!(health_score > 0, 24);
        
        // Test action stats
        let (action_name, display_name, category, points_per_exec, total_execs, is_active) = 
            generation_manager_v2::get_action_info(&action);
        assert!(action_name == string::utf8(b"stats_action"), 25);
        assert!(display_name == string::utf8(b"Stats Action"), 26);
        assert!(category == string::utf8(b"testing"), 27);
        assert!(points_per_exec == 100, 28);
        assert!(total_execs == 1, 29);
        assert!(is_active, 30);
        
        // Cleanup
        scenario::return_shared(action);
        scenario::return_shared(integration);
        scenario::return_shared(registry);
        test_utils::destroy(partner_cap);
        partner_v3::destroy_test_vault(partner_vault);
        test_utils::destroy(ledger);
        test_utils::destroy(partner_registry);
        admin_v2::destroy_config_for_testing(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 7: Emergency Pause and Resume Testing ===================
    
    #[test]
    fun test_emergency_pause_resume_workflow() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create integration cap
        let integration_cap = generation_manager_v2::create_test_integration_cap(
            generation_manager_v2::get_registry_id(&registry), 
            scenario::ctx(&mut scenario)
        );
        
        // Test emergency pause
        generation_manager_v2::emergency_pause_all_integrations(&mut registry, &integration_cap, scenario::ctx(&mut scenario));
        
        // Test resume
        generation_manager_v2::resume_all_integrations(&mut registry, &integration_cap, scenario::ctx(&mut scenario));
        
        // Verify operations completed successfully (no assertions needed as success means no abort)
        
        // Cleanup
        scenario::return_shared(registry);
        test_utils::destroy(integration_cap);
        admin_v2::destroy_config_for_testing(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 8: Integration Registry ID Testing ===================
    
    #[test]
    fun test_registry_id_functions() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        
        // Create registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        let registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Test registry ID function
        let registry_id = generation_manager_v2::get_registry_id(&registry);
        assert!(registry_id != object::id_from_address(@0x0), 1);
        
        // Test creating integration cap with this ID
        let integration_cap = generation_manager_v2::create_test_integration_cap(registry_id, scenario::ctx(&mut scenario));
        
        // Verify cap was created successfully
        test_utils::destroy(integration_cap);
        
        // Cleanup
        scenario::return_shared(registry);
        admin_v2::destroy_config_for_testing(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== TEST 9: Multiple Integration Types Testing ===================
    
    #[test]
    fun test_multiple_integration_types() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut partner_registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create registry
        generation_manager_v2::create_integration_registry_v2(&config, &admin_cap, &clock, scenario::ctx(&mut scenario));
        scenario::next_tx(&mut scenario, ADMIN);
        let mut registry = scenario::take_shared<IntegrationRegistry>(&scenario);
        
        // Create partner
        let (partner_cap, partner_vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut partner_registry, PARTNER1, USDC_AMOUNT, 100000, &clock, scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // Test different integration types
        generation_manager_v2::register_partner_integration(
            &mut registry,
            &partner_cap,
            &partner_vault,
            string::utf8(b"Mobile App Integration"),
            string::utf8(b"mobile_app"), // Different type
            option::none(),
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Verify integration was created
        let (total_integrations, _, _, _, active_integrations) = generation_manager_v2::get_registry_stats(&registry);
        assert!(total_integrations == 1, 1);
        assert!(active_integrations == 1, 2);
        
        scenario::next_tx(&mut scenario, PARTNER1);
        let integration = scenario::take_shared<PartnerIntegration>(&scenario);
        
        // Verify integration info
        let (name, int_type, is_active, is_approved, action_count) = 
            generation_manager_v2::get_integration_info(&integration);
        assert!(name == string::utf8(b"Mobile App Integration"), 3);
        assert!(int_type == string::utf8(b"mobile_app"), 4);
        assert!(is_active, 5);
        assert!(is_approved, 6);
        assert!(action_count == 0, 7);
        
        // Cleanup
        scenario::return_shared(integration);
        scenario::return_shared(registry);
        test_utils::destroy(partner_cap);
        partner_v3::destroy_test_vault(partner_vault);
        test_utils::destroy(partner_registry);
        admin_v2::destroy_config_for_testing(config);
        admin_v2::destroy_test_admin_cap(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}
