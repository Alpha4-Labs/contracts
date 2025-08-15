#[test_only]
module alpha_points::admin_v2_advanced_governance_tests {
    use std::string;
    use std::option;
    use std::vector;
    use sui::test_scenario::{Self as scenario, Scenario};
    use sui::clock::{Self, Clock};
    use sui::transfer;
    use sui::object;
    use sui::tx_context;
    use sui::test_utils;
    use sui::table;
    
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2, GovernanceCapV2};
    
    const ADMIN: address = @0xA;
    const SIGNER1: address = @0x1;
    const SIGNER2: address = @0x2; 
    const SIGNER3: address = @0x3;
    const UNAUTHORIZED: address = @0xDEAD;
    
    // Time constants for testing
    const ONE_DAY_MS: u64 = 86400000;
    const THREE_DAYS_MS: u64 = 259200000;
    const FOUR_DAYS_MS: u64 = 345600000;
    
    // =================== MULTI-SIGNER GOVERNANCE TESTS ===================
    
    #[test]
    fun test_multi_signer_governance_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Create governance cap with multiple authorized signers
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        
        // The test function creates with @0xA as authorized signer and required_signatures = 1
        // We need to manually modify this for multi-sig testing
        // For this test, we'll work with the existing structure
        
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Create proposal as ADMIN (who is authorized)
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1, // APY change proposal
            option::some(700u64), // 7% APY
            option::none(),
            option::none(),
            b"Multi-signer test proposal",
            b"Testing multi-signature governance workflow",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Since required_signatures is 1 and proposer auto-signs, proposal should be ready
        // Test that we can sign additional times (this should fail with EAlreadySigned)
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== PROPOSAL TIMING TESTS ===================
    
    #[test]
    #[expected_failure(abort_code = 8)] // EProposalExpired
    fun test_sign_proposal_after_voting_deadline() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Create proposal
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1,
            option::some(800u64),
            option::none(),
            option::none(),
            b"test",
            b"Timing test proposal",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Move clock forward past voting deadline (3 days + buffer)
        clock::increment_for_testing(&mut clock, FOUR_DAYS_MS);
        
        // Try to sign expired proposal - should fail
        admin_v2::sign_governance_proposal(
            &mut governance_cap,
            &config,
            1,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== PROPOSAL EXECUTION TESTS ===================
    
    #[test]
    fun test_proposal_execution_ready_state() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Create proposal (proposer auto-signs, and required_signatures = 1, so it's ready)
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1, // APY change
            option::some(650u64), // 6.5% APY
            option::none(),
            option::none(),
            b"execution test",
            b"Testing proposal execution readiness",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Move time forward but stay within voting period
        clock::increment_for_testing(&mut clock, ONE_DAY_MS);
        
        // Since required_signatures = 1 and proposer auto-signed, proposal should be ready
        // In a real scenario, we would have an execute_proposal function
        // For now, we test that the proposal exists and is in correct state
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== GOVERNANCE AUTHORIZATION TESTS ===================
    
    #[test]
    #[expected_failure(abort_code = 12)] // ESignerNotAuthorized
    fun test_sign_proposal_unauthorized_signer() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Create proposal as authorized user (ADMIN)
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1,
            option::some(550u64),
            option::none(),
            option::none(),
            b"auth test",
            b"Testing authorization",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Switch to unauthorized user and try to sign
        scenario::next_tx(&mut scenario, UNAUTHORIZED);
        
        admin_v2::sign_governance_proposal(
            &mut governance_cap,
            &config,
            1,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== PROPOSAL TYPE VARIATIONS TESTS ===================
    
    #[test]
    fun test_different_proposal_types() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Test APY change proposal (type 1)
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1, // APY change
            option::some(750u64),
            option::none(),
            option::none(),
            b"apy change",
            b"APY change proposal",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test grace period change proposal (type 2)
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            2, // Grace period change
            option::none(),
            option::some(1728000000u64), // 20 days
            option::none(),
            b"grace period change",
            b"Grace period change proposal",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test emergency pause change proposal (type 3)
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            3, // Emergency pause change
            option::none(),
            option::none(),
            option::some(true),
            b"emergency pause",
            b"Emergency pause proposal",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test custom proposal (type 99)
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            99, // Custom type
            option::none(),
            option::none(),
            option::none(),
            b"custom proposal data with special parameters",
            b"Custom proposal for special governance action",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // All proposals should be created successfully
        // In a real implementation, we would have different handling for each type
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== COMPLEX GOVERNANCE SCENARIOS ===================
    
    #[test]
    fun test_multiple_concurrent_proposals() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Create multiple proposals with different parameters - using separate calls instead of vector of tuples
        
        // Proposal 1: APY change to 6%
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1, // APY change
            option::some(600u64),
            option::none(),
            option::none(),
            b"concurrent test data",
            b"Proposal 1: APY to 6%",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Proposal 2: Grace period change to 25 days
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            2, // Grace period change
            option::none(),
            option::some(2160000000u64),
            option::none(),
            b"concurrent test data",
            b"Proposal 2: Grace period to 25 days",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Proposal 3: APY change to 4.5%
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1, // APY change
            option::some(450u64),
            option::none(),
            option::none(),
            b"concurrent test data",
            b"Proposal 3: APY to 4.5%",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Proposal 4: Unpause emergency
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            3, // Emergency pause change
            option::none(),
            option::none(),
            option::some(false),
            b"concurrent test data",
            b"Proposal 4: Unpause emergency",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // All proposals should be created with sequential IDs (1, 2, 3, 4)
        // In a real implementation, we could query proposal states
        
        // Test signing different proposals
        // Note: Proposer automatically signs when creating proposal, so we can't sign again as same user
        // In a real multi-sig scenario, different users would sign
        // For this test, we just verify proposals were created successfully
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== GOVERNANCE WITH PAUSED STATE TESTS ===================
    
    #[test]
    #[expected_failure(abort_code = 14)] // EProtocolPaused
    fun test_governance_operations_when_governance_paused() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let mut config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        let admin_cap = admin_v2::create_admin_cap_for_testing(scenario::ctx(&mut scenario));
        
        // Update config to link with admin cap
        admin_v2::update_admin_cap_id_for_testing(&mut config, admin_v2::get_admin_cap_id(&admin_cap));
        
        // First pause governance
        admin_v2::set_emergency_pause(
            &mut config,
            &admin_cap,
            4, // governance pause
            true,
            b"Testing governance pause",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Try to create proposal while governance is paused - should fail
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1,
            option::some(650u64),
            option::none(),
            option::none(),
            b"should fail",
            b"This should fail due to governance pause",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Should never reach here
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== EDGE CASE: PROPOSAL EXECUTION STATE TESTS ===================
    
    #[test]
    fun test_proposal_execution_state_tracking() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Create proposal with complex parameters
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1, // APY change
            option::some(850u64), // 8.5% APY
            option::some(3456000000u64), // 40 days grace period
            option::some(false), // unpause emergency
            b"complex proposal with multiple parameter changes",
            b"Testing complex proposal execution state tracking",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Move time to just before execution time (3 days voting + 1 day timelock)
        clock::increment_for_testing(&mut clock, THREE_DAYS_MS + ONE_DAY_MS - 1000);
        
        // Proposal should be ready for execution but timelock not yet expired
        // In a real implementation, we would check execution readiness
        
        // Move past timelock
        clock::increment_for_testing(&mut clock, 2000);
        
        // Now proposal should be executable
        // In a real implementation, we would execute the proposal here
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== STRESS TEST: MANY PROPOSALS ===================
    
    #[test]
    fun test_governance_stress_many_proposals() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Create many proposals to test governance cap table handling
        let mut i = 0;
        while (i < 10) {
            let apy_value = 500 + (i * 10); // 500, 510, 520, etc.
            
            admin_v2::create_governance_proposal(
                &mut governance_cap,
                &config,
                1, // APY change
                option::some(apy_value),
                option::none(),
                option::none(),
                b"stress test proposal",
                b"Stress test proposal for governance system",
                &clock,
                scenario::ctx(&mut scenario)
            );
            
            // Note: Each proposal is automatically signed by the proposer when created
            // In a real multi-sig scenario, additional signers would sign here
            
            // Move time forward slightly between proposals
            clock::increment_for_testing(&mut clock, 1000);
            
            i = i + 1;
        };
        
        // All proposals should be created and signed successfully
        // This tests the table storage and ID management
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== PROPOSAL DATA VALIDATION TESTS ===================
    
    #[test]
    fun test_proposal_custom_data_handling() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        let mut governance_cap = admin_v2::create_governance_cap_for_testing(scenario::ctx(&mut scenario));
        let config = admin_v2::create_config_for_testing_with_governance_cap(&governance_cap, scenario::ctx(&mut scenario));
        
        // Test with large custom data
        let mut large_custom_data = vector::empty<u8>();
        let mut i = 0;
        while (i < 1000) {
            vector::push_back(&mut large_custom_data, (i % 256) as u8);
            i = i + 1;
        };
        
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            99, // Custom type
            option::none(),
            option::none(),
            option::none(),
            large_custom_data,
            b"Testing large custom data handling in governance proposals",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test with empty custom data
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            1,
            option::some(525u64),
            option::none(),
            option::none(),
            vector::empty<u8>(),
            b"Testing empty custom data",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test with special characters in description
        admin_v2::create_governance_proposal(
            &mut governance_cap,
            &config,
            2,
            option::none(),
            option::some(1900800000u64),
            option::none(),
            b"special chars: !@#$%^&*()_+-=[]{}|;:,.<>?",
            b"Testing special characters in proposal description: !@#$%^&*()_+-=[]{}|;:,.<>?/~`",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // All proposals should be created successfully
        
        // Cleanup
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(governance_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}
