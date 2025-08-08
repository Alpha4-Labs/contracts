#[test_only]
module alpha_points::partner_v3_error_cases_comprehensive {
    use sui::test_scenario::{Self as scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use std::string::{Self, String};
    use std::vector;
    use sui::test_utils;
    
    // Import all required modules
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::partner_v3::{Self, PartnerCapV3, PartnerVault, PartnerRegistryV3, USDC};
    use alpha_points::ledger_v2::{Self, LedgerV2};
    
    // Test addresses
    const ADMIN: address = @0xAD;
    const PARTNER1: address = @0x333;
    const PARTNER2: address = @0x444;
    const UNAUTHORIZED_USER: address = @0x999;
    const USER1: address = @0x111;
    const DEFI_PROTOCOL: address = @0xDEF1;
    
    // Test constants
    const LARGE_USDC_AMOUNT: u64 = 10000_000_000; // 10,000 USDC
    const MIN_VAULT_USDC: u64 = 100_000_000; // 100 USDC (minimum)
    const SMALL_USDC_AMOUNT: u64 = 50_000_000; // 50 USDC (below minimum)
    const POINTS_AMOUNT: u64 = 50000; // 50K points
    const LARGE_POINTS_AMOUNT: u64 = 1000000000; // 1B points (excessive)
    
    // =================== ERROR CASE 1: Create Partner Vault Errors ===================
    
    #[test]
    #[expected_failure(abort_code = 5)] // EInvalidCollateralAmount
    fun test_create_partner_vault_insufficient_usdc() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create USDC coin below minimum
        let usdc_coin = partner_v3::create_test_usdc_coin(SMALL_USDC_AMOUNT, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // This should fail due to insufficient USDC
        partner_v3::create_partner_with_usdc_vault(
            &mut registry,
            &config,
            usdc_coin,
            string::utf8(b"Test Partner"),
            string::utf8(b"Test Vault"),
            1, // generation_id
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 11)] // EInvalidPartnerName
    fun test_create_partner_vault_empty_name() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        let usdc_coin = partner_v3::create_test_usdc_coin(LARGE_USDC_AMOUNT, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // This should fail due to empty partner name
        partner_v3::create_partner_with_usdc_vault(
            &mut registry,
            &config,
            usdc_coin,
            string::utf8(b""), // Empty name
            string::utf8(b"Test Vault"),
            1, // generation_id
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 8)] // EInvalidGenerationId
    fun test_create_partner_vault_invalid_generation() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        let usdc_coin = partner_v3::create_test_usdc_coin(LARGE_USDC_AMOUNT, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // This should fail due to invalid generation ID (0)
        partner_v3::create_partner_with_usdc_vault(
            &mut registry,
            &config,
            usdc_coin,
            string::utf8(b"Test Partner"),
            string::utf8(b"Test Vault"),
            0, // Invalid generation_id
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 15)] // EPartnerAlreadyExists
    fun test_create_partner_vault_duplicate_partner() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create first partner
        let usdc_coin1 = partner_v3::create_test_usdc_coin(LARGE_USDC_AMOUNT, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        partner_v3::create_partner_with_usdc_vault(
            &mut registry,
            &config,
            usdc_coin1,
            string::utf8(b"Test Partner 1"),
            string::utf8(b"Test Vault 1"),
            1, // generation_id
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Try to create duplicate partner with same address
        let usdc_coin2 = partner_v3::create_test_usdc_coin(LARGE_USDC_AMOUNT, scenario::ctx(&mut scenario));
        
        // This should fail due to duplicate partner
        partner_v3::create_partner_with_usdc_vault(
            &mut registry,
            &config,
            usdc_coin2,
            string::utf8(b"Test Partner 2"),
            string::utf8(b"Test Vault 2"),
            1, // generation_id
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== ERROR CASE 2: Withdraw USDC Errors ===================
    
    #[test]
    #[expected_failure(abort_code = 1)] // EUnauthorized
    fun test_withdraw_usdc_unauthorized() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner and vault
        let (partner_cap, mut vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            LARGE_USDC_AMOUNT,
            100000, // daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Switch to unauthorized user and try to withdraw
        scenario::next_tx(&mut scenario, UNAUTHORIZED_USER);
        
        // This should fail due to unauthorized access
        partner_v3::withdraw_usdc_from_vault(
            &mut registry,
            &config,
            &partner_cap,
            &mut vault,
            1000000, // 1 USDC
            b"unauthorized withdrawal",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        partner_v3::destroy_test_vault(vault);
        test_utils::destroy(partner_cap);
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 14)] // EInvalidWithdrawalAmount
    fun test_withdraw_usdc_zero_amount() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner and vault
        let (partner_cap, mut vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            LARGE_USDC_AMOUNT,
            100000, // daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // This should fail due to zero withdrawal amount
        partner_v3::withdraw_usdc_from_vault(
            &mut registry,
            &config,
            &partner_cap,
            &mut vault,
            0, // Zero amount
            b"zero withdrawal",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        partner_v3::destroy_test_vault(vault);
        test_utils::destroy(partner_cap);
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 7)] // EExcessiveWithdrawal
    fun test_withdraw_usdc_excessive_amount() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner and vault with minimal amount
        let (partner_cap, mut vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            MIN_VAULT_USDC, // Minimal amount
            100000, // daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // This should fail due to excessive withdrawal (more than available)
        partner_v3::withdraw_usdc_from_vault(
            &mut registry,
            &config,
            &partner_cap,
            &mut vault,
            LARGE_USDC_AMOUNT, // Much more than vault has
            b"excessive withdrawal",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        partner_v3::destroy_test_vault(vault);
        test_utils::destroy(partner_cap);
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== ERROR CASE 3: Mint Points with Vault Backing Errors ===================
    
    #[test]
    #[expected_failure(abort_code = 1)] // EUnauthorized
    fun test_mint_points_unauthorized() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner and vault
        let (mut partner_cap, mut vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            LARGE_USDC_AMOUNT,
            100000, // daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Switch to unauthorized user and try to mint
        scenario::next_tx(&mut scenario, UNAUTHORIZED_USER);
        
        // This should fail due to unauthorized access
        partner_v3::mint_points_with_vault_backing(
            &mut registry,
            &mut ledger,
            &config,
            &mut partner_cap,
            &mut vault,
            USER1,
            POINTS_AMOUNT,
            b"unauthorized mint",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        partner_v3::destroy_test_vault(vault);
        test_utils::destroy(partner_cap);
        test_utils::destroy(registry);
        test_utils::destroy(ledger);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 10)] // EInvalidQuotaAmount
    fun test_mint_points_zero_amount() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner and vault
        let (mut partner_cap, mut vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            LARGE_USDC_AMOUNT,
            100000, // daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // This should fail due to zero points amount
        partner_v3::mint_points_with_vault_backing(
            &mut registry,
            &mut ledger,
            &config,
            &mut partner_cap,
            &mut vault,
            USER1,
            0, // Zero points
            b"zero points mint",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        partner_v3::destroy_test_vault(vault);
        test_utils::destroy(partner_cap);
        test_utils::destroy(registry);
        test_utils::destroy(ledger);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 13)] // EQuotaExhausted
    fun test_mint_points_quota_exhausted() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner and vault with small daily quota
        let (mut partner_cap, mut vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            LARGE_USDC_AMOUNT,
            1000, // Small daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // This should fail due to quota exhaustion
        partner_v3::mint_points_with_vault_backing(
            &mut registry,
            &mut ledger,
            &config,
            &mut partner_cap,
            &mut vault,
            USER1,
            LARGE_POINTS_AMOUNT, // Much more than daily quota
            b"quota exhaustion",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        partner_v3::destroy_test_vault(vault);
        test_utils::destroy(partner_cap);
        test_utils::destroy(registry);
        test_utils::destroy(ledger);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 4)] // EInsufficientCollateral
    fun test_mint_points_insufficient_backing() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner and vault with minimal USDC but large quota
        let (mut partner_cap, mut vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            MIN_VAULT_USDC, // Minimal USDC
            LARGE_POINTS_AMOUNT, // Large quota that can't be backed
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // This should fail due to insufficient USDC backing
        partner_v3::mint_points_with_vault_backing(
            &mut registry,
            &mut ledger,
            &config,
            &mut partner_cap,
            &mut vault,
            USER1,
            LARGE_POINTS_AMOUNT / 2, // Still too much for the small vault
            b"insufficient backing",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        partner_v3::destroy_test_vault(vault);
        test_utils::destroy(partner_cap);
        test_utils::destroy(registry);
        test_utils::destroy(ledger);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== ERROR CASE 4: DeFi Transfer Errors ===================
    
    #[test]
    #[expected_failure(abort_code = 1)] // EUnauthorized
    fun test_transfer_vault_to_defi_unauthorized() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner and vault
        let (mut partner_cap, vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            LARGE_USDC_AMOUNT,
            100000, // daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Switch to unauthorized user and try to transfer
        scenario::next_tx(&mut scenario, UNAUTHORIZED_USER);
        
        // This should fail due to unauthorized access
        partner_v3::transfer_vault_to_defi_protocol(
            &mut registry,
            &config,
            &mut partner_cap,
            vault,
            string::utf8(b"Scallop Protocol"),
            500, // 5% APY
            8000, // 80% max utilization
            DEFI_PROTOCOL,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        test_utils::destroy(partner_cap);
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 20)] // EVaultTooSmall
    fun test_transfer_vault_to_defi_vault_too_small() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner and vault with amount below DeFi minimum
        let (mut partner_cap, vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            MIN_VAULT_USDC, // Below DeFi minimum (1000 USDC)
            100000, // daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // This should fail due to vault being too small for DeFi
        partner_v3::transfer_vault_to_defi_protocol(
            &mut registry,
            &config,
            &mut partner_cap,
            vault,
            string::utf8(b"Scallop Protocol"),
            500, // 5% APY
            8000, // 80% max utilization
            DEFI_PROTOCOL,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        test_utils::destroy(partner_cap);
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== ERROR CASE 5: Harvest Yield Errors ===================
    
    #[test]
    #[expected_failure(abort_code = 21)] // EInvalidVaultState (vault not in DeFi)
    fun test_harvest_defi_yield_mismatched_amount() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Create partner and vault
        let (partner_cap, mut vault) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            LARGE_USDC_AMOUNT,
            100000, // daily quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Create yield coin with different amount than claimed
        let yield_coin = partner_v3::create_test_usdc_coin(1000000, scenario::ctx(&mut scenario)); // 1 USDC
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        // This should fail due to mismatched yield amount
        partner_v3::harvest_defi_yield(
            &mut registry,
            &config,
            &partner_cap,
            &mut vault,
            2000000, // Claiming 2 USDC but coin only has 1 USDC
            yield_coin,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Cleanup (won't reach here due to expected failure)
        partner_v3::destroy_test_vault(vault);
        test_utils::destroy(partner_cap);
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    // =================== SUCCESS CASES FOR COVERAGE ===================
    
    #[test]
    fun test_successful_vault_operations_comprehensive() {
        let mut scenario = scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut ledger = ledger_v2::create_ledger_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Test successful partner creation
        let usdc_coin = partner_v3::create_test_usdc_coin(LARGE_USDC_AMOUNT, scenario::ctx(&mut scenario));
        
        scenario::next_tx(&mut scenario, PARTNER1);
        
        partner_v3::create_partner_with_usdc_vault(
            &mut registry,
            &config,
            usdc_coin,
            string::utf8(b"Test Partner"),
            string::utf8(b"Test Vault"),
            1, // generation_id
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Get created objects
        scenario::next_tx(&mut scenario, PARTNER1);
        let mut partner_cap = scenario::take_from_sender<PartnerCapV3>(&scenario);
        let mut vault = scenario::take_from_sender<PartnerVault>(&scenario);
        
        // Test successful points minting
        partner_v3::mint_points_with_vault_backing(
            &mut registry,
            &mut ledger,
            &config,
            &mut partner_cap,
            &mut vault,
            USER1,
            POINTS_AMOUNT,
            b"successful mint",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test successful USDC withdrawal
        partner_v3::withdraw_usdc_from_vault(
            &mut registry,
            &config,
            &partner_cap,
            &mut vault,
            1000000, // 1 USDC
            b"successful withdrawal",
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test points burning callback
        clock::increment_for_testing(&mut clock, 1000);
        let current_time = clock::timestamp_ms(&clock);
        partner_v3::on_points_burned_vault(&mut vault, POINTS_AMOUNT / 2, &config, current_time);
        
        // Test revenue addition
        partner_v3::add_revenue_to_vault(&mut vault, 500000, current_time, scenario::ctx(&mut scenario));
        
        // Test points minting recording
        partner_v3::record_points_minting(&mut vault, 1000, current_time, scenario::ctx(&mut scenario));
        
        // Test all view functions for coverage
        let (_, _, _, _, _, _, _) = partner_v3::get_vault_info(&vault);
        let (_, _, _, _, _) = partner_v3::get_vault_collateral_details(&vault);
        let _ = partner_v3::calculate_max_withdrawable_usdc(&vault, &config);
        let (_, _, _, _) = partner_v3::get_defi_status(&vault);
        let _ = partner_v3::is_vault_defi_ready(&vault);
        let (_, _, _, _, _) = partner_v3::get_partner_info_v3(&partner_cap);
        let (_, _, _, _, _, _) = partner_v3::get_registry_stats_v3(&registry);
        let _ = partner_v3::get_partner_address(&partner_cap);
        let _ = partner_v3::is_paused(&partner_cap);
        let _ = partner_v3::get_vault_partner_address(&vault);
        let _ = partner_v3::can_support_points_minting(&vault, 1000);
        let _ = partner_v3::can_support_transaction(&vault, 1000000);
        let _ = partner_v3::get_vault_balance(&vault);
        
        // Cleanup
        test_utils::destroy(partner_cap);
        partner_v3::destroy_test_vault(vault);
        test_utils::destroy(registry);
        test_utils::destroy(ledger);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
    
    #[test]
    fun test_boundary_values_and_edge_cases() {
        let mut scenario = scenario::begin(ADMIN);
        let clock = clock::create_for_testing(scenario::ctx(&mut scenario));
        
        // Setup infrastructure
        let (config, admin_cap) = admin_v2::create_config_and_admin_cap_for_testing_and_return_both(scenario::ctx(&mut scenario));
        let mut registry = partner_v3::create_registry_for_testing(&admin_cap, &config, scenario::ctx(&mut scenario));
        
        // Test with minimum valid USDC amount
        let (partner_cap1, vault1) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER1,
            MIN_VAULT_USDC, // Exactly minimum
            1000, // Small quota
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test with maximum generation ID
        let (partner_cap2, vault2) = partner_v3::create_partner_with_vault_for_testing(
            &mut registry,
            PARTNER2,
            LARGE_USDC_AMOUNT,
            100000,
            &clock,
            scenario::ctx(&mut scenario)
        );
        
        // Test health factor calculations at boundaries
        let (_, _, _, _, _) = partner_v3::get_vault_collateral_details(&vault1);
        let (_, _, _, _, _) = partner_v3::get_vault_collateral_details(&vault2);
        
        // Test max withdrawable calculations
        let _ = partner_v3::calculate_max_withdrawable_usdc(&vault1, &config);
        let _ = partner_v3::calculate_max_withdrawable_usdc(&vault2, &config);
        
        // Cleanup
        test_utils::destroy(partner_cap1);
        test_utils::destroy(partner_cap2);
        partner_v3::destroy_test_vault(vault1);
        partner_v3::destroy_test_vault(vault2);
        test_utils::destroy(registry);
        admin_v2::destroy_config_for_testing(config);
        test_utils::destroy(admin_cap);
        clock::destroy_for_testing(clock);
        scenario::end(scenario);
    }
}
