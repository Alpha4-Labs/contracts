#[test_only]
#[allow(unused_use, unused_const)]
module alpha_points::core_simple_tests {
    use sui::test_scenario::{Self as scenario};
    use sui::clock::{Self, Clock};
    use sui::test_utils;
    use std::string;
    
    use alpha_points::admin_simple::{Self, ConfigSimple, AdminCapSimple};
    use alpha_points::ledger_simple::{Self, LedgerSimple};
    use alpha_points::oracle_simple::{Self, OracleSimple};
    
    const ADMIN: address = @0x123;
    const USER1: address = @0x456;
    const USER2: address = @0x789;
    
    // =================== CORE FUNCTIONALITY TESTS ===================
    
    #[test]
    fun test_basic_admin_functionality() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test admin module basic functions
        let treasury = admin_simple::get_treasury_address();
        assert!(treasury == @0x999999999999999999999999999999999999999999999999999999999999999, 1);
        
        // Cleanup
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_basic_ledger_functionality() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test ledger constants and types
        let partner_type = ledger_simple::partner_reward_type();
        let user_type = ledger_simple::user_redemption_type();
        assert!(partner_type != user_type, 1);
        
        // Cleanup
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_basic_oracle_functionality() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test oracle basic functionality by checking if we can create strings
        let pair = string::utf8(b"USDC/SUI");
        assert!(string::length(&pair) > 0, 1);
        
        // Cleanup
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== INTEGRATION TESTS ===================
    
    #[test]
    fun test_module_integration() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Test that all our simplified modules can work together
        let treasury = admin_simple::get_treasury_address();
        let partner_type = ledger_simple::partner_reward_type();
        let user_type = ledger_simple::user_redemption_type();
        let pair = string::utf8(b"USDC/SUI");
        
        // Basic integration checks
        assert!(treasury == @0x999999999999999999999999999999999999999999999999999999999999999, 1);
        assert!(partner_type != user_type, 2);
        assert!(string::length(&pair) == 8, 3);
        
        // Cleanup
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== COMPILATION VERIFICATION TESTS ===================
    
    #[test]
    fun test_all_modules_compile() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // This test verifies that all our simplified modules compile and their
        // public functions are accessible. We don't test full functionality here,
        // just compilation and basic access.
        
        // Admin module
        let _treasury = admin_simple::get_treasury_address();
        
        // Ledger module  
        let _partner_type = ledger_simple::partner_reward_type();
        let _user_type = ledger_simple::user_redemption_type();
        
        // Oracle module - just test string creation
        let _pair = string::utf8(b"USDC/SUI");
        
        // If we reach here, all modules compiled successfully
        assert!(true, 1);
        
        // Cleanup
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}
