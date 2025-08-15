/// Module that handles the logic for borrowing Alpha Points against staked assets.
module alpha_points::loan {
    // use sui::object; // Removed as provided by default
    // use sui::transfer; // Removed, provided by default
    // use sui::tx_context; // Removed as provided by default
    use sui::event;
    use sui::clock::{Self as clock, Clock};
    // use std::option; // Removed, provided by default
    // use std::string::String; // String alias removed, string module itself might be unused if no other members are used
    use alpha_points::admin::{Self, Config, GovernCap};
    use alpha_points::ledger::{Self as ledger, Ledger};
    use alpha_points::oracle::{Self as oracle, RateOracle};
    use alpha_points::stake_position::{Self as stake_position, StakePosition};
    use alpha_points::partner::{Self as partner, PartnerCap};
    use alpha_points::partner_flex::{Self as partner_flex, PartnerCapFlex}; // Added for new TVL-backed system
    use sui::object::{new as object_new}; // Changed import: ID and UID will be fully qualified
    // use sui::balance::{Self, Balance}; // Self (balance) and Balance removed as unused
    // use sui::coin::Coin; // Coin alias removed as unused
    // use sui::sui::SUI; // SUI alias removed as unused
    // use std::vector; // Removed, provided by default
    
    // Error constants
    const EInvalidLoanAmount: u64 = 1;
    const EExceedsLTV: u64 = 2;
    const EStakeAlreadyEncumbered: u64 = 3;
    const EWrongStake: u64 = 4;
    const EInsufficientPoints: u64 = 5;
    const EUnauthorized: u64 = 6;
    const EFeeCalculationError: u64 = 7; // Added for fee errors

    // Time Constants // MS_PER_DAY removed as unused
    // const MS_PER_DAY: u64 = 24 * 60 * 60 * 1000;
    
    /// Shared object for loan parameters
    public struct LoanConfig has key {
        id: object::UID,
        max_ltv_bps: u64,         // Maximum loan-to-value ratio in basis points (e.g., 7000 = 70%)
        interest_rate_bps: u64    // Annual interest rate in basis points (e.g., 500 = 5%)
    }
    
    /// Owned object representing an active loan tied to a StakePosition
    public struct Loan has key, store {
        id: object::UID,
        borrower: address,
        stake_id: object::ID,
        principal_points: u64,
        interest_owed_points: u64, // Note: Currently unused/not accrued
        opened_time_ms: u64       // Changed from opened_epoch
    }
    
    // Events
    public struct LoanConfigInitialized has copy, drop {
        id: object::ID,
        max_ltv_bps: u64,
        interest_rate_bps: u64
    }
    
    public struct LoanOpened<phantom T> has copy, drop {
        id: object::ID,
        borrower: address,
        stake_id: object::ID,
        principal_points: u64,
        opened_time_ms: u64     // Changed from opened_epoch
    }
    
    public struct LoanRepaid<phantom T> has copy, drop {
        id: object::ID,
        borrower: address,
        stake_id: object::ID,
        principal_points: u64,
        interest_paid_points: u64,
        total_paid_points: u64
    }
    
    /// Event emitted for partner attribution in loan module
    public struct LoanPartnerAttribution has copy, drop {
        partner_address: address,
        user: address,
        action: vector<u8>,
        amount: u64,
        fee_share: u64
    }
    
    // === Core module functions ===
    
    /// Creates a new Loan object. Intended for use within the alpha_points package.
    public(package) fun create_loan(
        borrower: address,
        stake_id: object::ID,
        principal_points: u64,
        opened_time_ms: u64,
        ctx: &mut tx_context::TxContext
    ): Loan {
        Loan {
            id: object_new(ctx),
            borrower,
            stake_id,
            principal_points,
            interest_owed_points: 0, // Default new loans to 0 interest owed
            opened_time_ms
        }
    }

    /// Public getter for the Loan object's UID.
    public fun get_loan_uid(loan: &Loan): &object::UID {
        &loan.id
    }
    
    /// Creates and shares LoanConfig
    public entry fun init_loan_config(
        _gov_cap: &GovernCap,
        max_ltv_bps: u64,
        interest_rate_bps: u64,
        ctx: &mut tx_context::TxContext
    ) {
        // Validate inputs
        assert!(max_ltv_bps <= 9000, 0); // Max 90% LTV
        assert!(interest_rate_bps <= 10000, 0); // Max 100% interest
        
        let id = object::new(ctx);
        
        // Create loan config
        let loan_config = LoanConfig {
            id,
            max_ltv_bps,
            interest_rate_bps
        };
        
        // Emit event
        event::emit(LoanConfigInitialized {
            id: object::uid_to_inner(&loan_config.id),
            max_ltv_bps,
            interest_rate_bps
        });
        
        // Share the config
        transfer::share_object(loan_config);
    }
    
    /// Opens a loan against a stake position
    /// @deprecated Use open_loan_with_partner_flex for TVL-backed quota validation
    public entry fun open_loan<T: store>(
        config: &Config,
        loan_config: &LoanConfig,
        ledger: &mut Ledger,
        stake: &mut StakePosition<T>,
        rate_oracle_param: &RateOracle,
        amount_points: u64,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        admin::assert_not_paused(config);
        assert!(amount_points > 0, EInvalidLoanAmount);
        let borrower = tx_context::sender(ctx);
        assert!(stake_position::owner_view(stake) == borrower, EUnauthorized);
        assert!(!stake_position::is_encumbered_view(stake), EStakeAlreadyEncumbered);
        let stake_principal = stake_position::principal_view(stake);
        let (rate, decimals) = oracle::get_rate(rate_oracle_param);
        let stake_value_in_points = oracle::convert_asset_to_points(
            stake_principal,
            rate,
            decimals
        );
        let max_loanable_points = (stake_value_in_points * loan_config.max_ltv_bps) / 10000;
        assert!(amount_points <= max_loanable_points, EExceedsLTV);
        stake_position::set_encumbered(stake, true);
        let stake_id = stake_position::get_id_view(stake);
        let opened_time_ms = clock::timestamp_ms(clock);
        let fee_points = amount_points / 1000; 
        let borrower_points = amount_points - fee_points;
        if (fee_points > amount_points) { abort EFeeCalculationError };
        if (fee_points > 0) {
            ledger::internal_earn(ledger, admin::deployer_address(config), fee_points, ctx);
        };
        let stake_opt = std::option::none<StakePosition<T>>();
        ledger::mint_points<T>(ledger, borrower, borrower_points, ledger::new_point_type_staking(), ctx, &stake_opt, 0, clock);
        option::destroy_none(stake_opt);
        let loan = Loan {
            id: object::new(ctx),
            borrower,
            stake_id,
            principal_points: amount_points, 
            interest_owed_points: 0, 
            opened_time_ms
        };
        event::emit(LoanOpened<T> {
            id: object::uid_to_inner(&loan.id),
            borrower,
            stake_id,
            principal_points: amount_points, 
            opened_time_ms
        });
        transfer::public_transfer(loan, borrower);
    }
    
    /// Opens a loan against a stake position WITH partner attribution
    public entry fun open_loan_with_partner<T: store>(
        config: &Config,
        loan_config: &LoanConfig,
        partner_cap: &PartnerCap,
        ledger: &mut Ledger,
        stake: &mut StakePosition<T>,
        oracle: &RateOracle,
        amount_points: u64,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        admin::assert_not_paused(config);
        assert!(amount_points > 0, EInvalidLoanAmount);
        let borrower = tx_context::sender(ctx);
        assert!(stake_position::owner_view(stake) == borrower, EUnauthorized);
        assert!(!stake_position::is_encumbered_view(stake), EStakeAlreadyEncumbered);
        let stake_principal = stake_position::principal_view(stake);
        let (rate, decimals) = oracle::get_rate(oracle);
        let stake_value_in_points = oracle::convert_asset_to_points(
            stake_principal,
            rate,
            decimals
        );
        let max_loanable_points = (stake_value_in_points * loan_config.max_ltv_bps) / 10000;
        assert!(amount_points <= max_loanable_points, EExceedsLTV);
        stake_position::set_encumbered(stake, true);
        let stake_id = stake_position::get_id_view(stake);
        let opened_time_ms = clock::timestamp_ms(clock);
        let fee_points = amount_points / 1000; 
        let borrower_points = amount_points - fee_points;
        if (fee_points > amount_points) { abort EFeeCalculationError };
        let partner_addr = object::uid_to_address(partner::get_id(partner_cap));
        let partner_share = fee_points / 5; // 20% to partner
        let deployer_share = fee_points - partner_share;
        if (partner_share > 0) {
            ledger::internal_earn(ledger, partner_addr, partner_share, ctx);
            event::emit(LoanPartnerAttribution {
                partner_address: partner_addr,
                user: borrower,
                action: b"open_loan_with_partner",
                amount: amount_points,
                fee_share: partner_share
            });
        };
        if (deployer_share > 0) {
            ledger::internal_earn(ledger, admin::deployer_address(config), deployer_share, ctx);
        };
        let stake_opt = std::option::none<StakePosition<T>>();
        ledger::mint_points<T>(ledger, borrower, borrower_points, ledger::new_point_type_staking(), ctx, &stake_opt, 0, clock);
        option::destroy_none(stake_opt);
        let loan = Loan {
            id: object::new(ctx),
            borrower,
            stake_id,
            principal_points: amount_points, 
            interest_owed_points: 0, 
            opened_time_ms
        };
        event::emit(LoanOpened<T> {
            id: object::uid_to_inner(&loan.id),
            borrower,
            stake_id,
            principal_points: amount_points, 
            opened_time_ms
        });
        transfer::public_transfer(loan, borrower);
    }
    
    /// Opens a loan against a stake position with TVL-backed PartnerCapFlex
    /// This function validates against the partner's quota and includes enhanced revenue split
    public entry fun open_loan_with_partner_flex<T: store>(
        config: &Config,
        loan_config: &LoanConfig,
        partner_cap: &mut PartnerCapFlex,
        ledger: &mut Ledger,
        stake: &mut StakePosition<T>,
        oracle: &RateOracle,
        amount_points: u64,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        admin::assert_not_paused(config);
        assert!(amount_points > 0, EInvalidLoanAmount);
        let borrower = tx_context::sender(ctx);
        assert!(stake_position::owner_view(stake) == borrower, EUnauthorized);
        assert!(!stake_position::is_encumbered_view(stake), EStakeAlreadyEncumbered);
        
        // Validate that partner can mint the loan amount within their quota
        let current_epoch = tx_context::epoch(ctx);
        partner_flex::validate_mint_quota(partner_cap, amount_points, current_epoch, ctx);
        
        let stake_principal = stake_position::principal_view(stake);
        let (rate, decimals) = oracle::get_rate(oracle);
        let stake_value_in_points = oracle::convert_asset_to_points(
            stake_principal,
            rate,
            decimals
        );
        let max_loanable_points = (stake_value_in_points * loan_config.max_ltv_bps) / 10000;
        assert!(amount_points <= max_loanable_points, EExceedsLTV);
        
        stake_position::set_encumbered(stake, true);
        let stake_id = stake_position::get_id_view(stake);
        let opened_time_ms = clock::timestamp_ms(clock);
        let fee_points = amount_points / 1000; 
        let borrower_points = amount_points - fee_points;
        if (fee_points > amount_points) { abort EFeeCalculationError };
        
        // Record the points minted against partner's quota
        partner_flex::record_points_minted(partner_cap, amount_points, current_epoch, ctx);
        
        let partner_addr = partner_flex::partner_address(partner_cap);
        let partner_share = fee_points / 5; // 20% to partner
        let deployer_share = fee_points - partner_share;
        
        if (partner_share > 0) {
            ledger::internal_earn(ledger, partner_addr, partner_share, ctx);
            event::emit(LoanPartnerAttribution {
                partner_address: partner_addr,
                user: borrower,
                action: b"open_loan_with_partner_flex",
                amount: amount_points,
                fee_share: partner_share
            });
        };
        
        if (deployer_share > 0) {
            ledger::internal_earn(ledger, admin::deployer_address(config), deployer_share, ctx);
        };
        
        let stake_opt = std::option::none<StakePosition<T>>();
        ledger::mint_points<T>(ledger, borrower, borrower_points, ledger::new_point_type_staking(), ctx, &stake_opt, 0, clock);
        option::destroy_none(stake_opt);
        
        let loan = Loan {
            id: object::new(ctx),
            borrower,
            stake_id,
            principal_points: amount_points, 
            interest_owed_points: 0, 
            opened_time_ms
        };
        
        event::emit(LoanOpened<T> {
            id: object::uid_to_inner(&loan.id),
            borrower,
            stake_id,
            principal_points: amount_points, 
            opened_time_ms
        });
        
        transfer::public_transfer(loan, borrower);
    }
    
    /// Repays a loan and releases the stake
    public entry fun repay_loan<T: store>(
        config: &Config,
        ledger: &mut Ledger,
        loan: Loan,
        stake: &mut StakePosition<T>,
        points_to_repay: u64, // This is the amount of points the user is sending for repayment
        ctx: &mut tx_context::TxContext
    ) {
        admin::assert_not_paused(config);
        let borrower = tx_context::sender(ctx);
        assert!(loan.borrower == borrower, EUnauthorized);
        assert!(stake_position::get_id_view(stake) == loan.stake_id, EWrongStake);
        // For now, assume interest is 0 or handled externally if accrued.
        let total_repayment = loan.principal_points; 

        assert!(points_to_repay >= total_repayment, EInsufficientPoints);

        ledger::internal_spend(ledger, borrower, total_repayment, ctx);

        stake_position::set_encumbered(stake, false);
        event::emit(LoanRepaid<T> {
            id: object::uid_to_inner(&loan.id),
            borrower,
            stake_id: loan.stake_id,
            principal_points: loan.principal_points,
            interest_paid_points: 0,
            total_paid_points: total_repayment
        });
        let Loan { id, borrower: _, stake_id: _, principal_points: _, interest_owed_points: _, opened_time_ms: _ } = loan;
        object::delete(id);
    }
    
    /// Calculate interest based on principal, elapsed time (ms), and annual rate (bps)
    public fun calculate_interest(
        _loan_config: &LoanConfig,
        _principal: u64,
        _elapsed_ms: u64
    ): u64 {
        let _numerator1 = (_principal * _loan_config.interest_rate_bps);
        let _numerator2 = (_numerator1 * _elapsed_ms);
        let denominator = (10000 * 86_400_000);
        if (denominator == 0) { return 0 };
        (_numerator2 / denominator)
    }

    // === View functions ===
    
    /// Get loan details (principal, interest owed (currently always 0), opened time ms)
    public fun get_loan_details(loan: &Loan): (u64, u64, u64) {
        (loan.principal_points, loan.interest_owed_points, loan.opened_time_ms)
    }
    
    /// Get current repayment amount including accrued interest.
    /// WARNING: Accrued interest calculation is currently a placeholder and returns 0.
    /// A proper implementation requires access to LoanConfig or calculation during repayment.
    public fun get_current_repayment_amount(
        loan: &Loan,
        clock: &Clock
    ): (u64, u64) { 
        let current_time_ms = clock::timestamp_ms(clock);
        
        // Ensure current time is after loan opened time
        if (current_time_ms < loan.opened_time_ms) {
            // Should not happen in normal flow, but handle defensively
            return (loan.principal_points, 0) 
        };
        
        let _elapsed_ms = current_time_ms - loan.opened_time_ms;
        
        // Placeholder for accrued interest calculation
        // TODO: Implement proper interest calculation, likely needing LoanConfig access
        // Or perform calculation within the repay_loan function itself.
        // Commenting out placeholder for now to allow compilation
        /*
        let loan_manager = LOAN_MANAGER_PLACEHOLDER; // ASCII Placeholder
        let loan_config_for_calc = get_loan_config(loan_manager; // Placeholder function call
        let accrued_interest = calculate_interest(loan_config_for_calc, loan.principal_points, elapsed_ms);
        */
        let accrued_interest = 0; // Defaulting to 0 as placeholder logic is commented out
        
        let total_repayment = loan.principal_points + accrued_interest;
        
        (total_repayment, accrued_interest)
    }
    
    /// Get the borrower of a loan
    public fun get_borrower(loan: &Loan): address {
        loan.borrower
    }
    
    /// Get the stake ID associated with a loan
    public fun get_stake_id(loan: &Loan): object::ID {
        loan.stake_id
    }
}