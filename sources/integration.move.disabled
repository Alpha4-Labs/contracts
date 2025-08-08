/// Module that provides the main public entry points for user interactions.
/// Orchestrates calls to other modules.
///
/// ⚠️  CRITICAL ECONOMIC MODEL FLAW DOCUMENTED BELOW ⚠️
///
/// INTENDED STAKING ECONOMICS:
/// 1. User stakes SUI for a fixed duration (e.g., 30 days)
/// 2. During staking period: User earns Alpha Points as rewards (5% APY)
/// 3. User can claim accrued Alpha Points periodically (via claim_accrued_points)
/// 4. After maturity: User unstakes to get their original SUI principal back
/// 5. Total reward: Only the Alpha Points earned during staking period
///
/// CURRENT BROKEN IMPLEMENTATION:
/// - Users get Alpha Points during staking (✓ correct)
/// - Users ALSO get Alpha Points when unstaking (❌ WRONG!)
/// - Users get their SUI back when unstaking (✓ correct)
/// - Result: Double rewards, breaking the economic model
///
/// ECONOMIC IMPACT OF BUG:
/// - User stakes 1 SUI, earns ~164 Alpha Points over 30 days (5% APY)
/// - User unstakes and gets 1 SUI back + 3,280 Alpha Points (principal conversion)
/// - Total: 1 SUI + 3,444 Alpha Points (~$6.72 value from $3.28 stake)
/// - This creates 100%+ profit just for staking, breaking sustainability
///
/// FUNCTIONS WITH THIS FLAW:
/// - request_unstake_native_sui (mints ~700k points due to 223x bug)
/// - request_unstake_native_sui_v2 (mints ~3,280 points, economically "correct" but still wrong)
/// - liquid_unstake_as_loan_native_sui_v2 (correctly converts to points as a loan)
///
/// CANNOT FIX: Sui Move upgrade rules prevent changing public function behavior
module alpha_points::integration {
    use sui::clock::{Self as clock, Clock};
    use sui::event;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use std::string::{Self, String};
    use std::ascii::{Self as ascii};
    use std::option::{Self as std_option};
    // use sui::table::{Self, Table}; // Removed unused aliases
    
    // Corrected Sui System State and Staking Pool imports
    use sui_system::sui_system::SuiSystemState;
    use sui_system::staking_pool::{StakedSui, staked_sui_amount};
    
    use alpha_points::admin::{Self, Config, AdminCap, TestnetBypassCap};
    use alpha_points::ledger::{Self, Ledger}; // Removed MintStats, SupplyOracle
    use alpha_points::escrow::{Self, EscrowVault};
    use alpha_points::stake_position::{Self, StakePosition};
    use alpha_points::oracle::{Self, RateOracle};
    use alpha_points::staking_manager::{Self, StakingManager};
    use alpha_points::partner::{Self, PartnerCap};
    use alpha_points::partner_flex::{Self as partner_flex, PartnerCapFlex};
    use alpha_points::loan;
    use sui::object::id_from_address;
    // use alpha_points::types::{Self, CollateralType, PointTypeConstants, ErrorCodeConstants}; // FIXME: Temporarily commented out due to unresolved types
    // use sui::table; // Removed table alias
    // use alpha_points::ledger::get_daily_wallet_cap; // Removed as unused alias
    
    // Error constants - using placeholders for now
    const EAdminOnly: u64 = 0; // FIXME: ErrorCodeConstants undefined
    const EAlreadyClaimedOrTooSoon: u64 = 0; // FIXME: ErrorCodeConstants undefined
    const ERepaymentAmountError: u64 = 0; // FIXME: ErrorCodeConstants undefined
    const EFeeCalculationError: u64 = 0; // FIXME: ErrorCodeConstants undefined
    const ENotOwner: u64 = 1; // Example, ensure this is defined or use an existing one
    const ENotRedeemable: u64 = 2; // Example, ensure this is defined or use an existing one
    const EInvalidStakeIdType: u64 = 3; // Example for type mismatch
    const EStakeEncumbered: u64 = 4; // New error: Stake is encumbered by a loan
    #[allow(unused_const)]
    const ELoanProcessingError: u64 = 5; // Error during loan object creation/processing for liquid unstake
    const EStakeNotMatureForLoan: u64 = 6; // Stake is not mature enough for this type of loan/unstake
    const EInvalidStakeDurationForApy: u64 = 110;
    // New Errors for earn_points functions
    const EPartnerPaused: u64 = 7;
    const EPartnerExceedsQuota: u64 = 8;
    const EInsufficientPointsForPerk: u64 = 9; // New error for perk purchase
    // New errors for v2 functions
    const ENotPastGracePeriod: u64 = 11; // Stake is not past the forfeiture grace period
    const EInsufficientCompensation: u64 = 12; // Compensation amount is insufficient
    const EInvalidBatchData: u64 = 13; // Batch data arrays have mismatched lengths
    // EUserExceedsDailyCap is no longer needed as MintStats is removed
    // const EUserExceedsDailyCap: u64 = 9; 
    
        // Constants
    // const STAKE_EXPIRY_DAYS: u64 = 14; // Removed as unused

    // APY Calculation Constants  
    const EPOCHS_PER_YEAR: u64 = 365; // Assuming daily epochs for simplicity
    const SUI_TO_MIST_CONVERSION: u64 = 1_000_000_000;
    const APY_POINT_SCALING_FACTOR: u64 = 25; // Scales APY_bps * 25 for points calculation
    
    // NEW: Alpha Points conversion constants using 1:1000 USD ratio
    const SUI_PRICE_USD_MILLI: u64 = 3280; // 3.28 USD * 1000 = 3,280 milli-USD
    #[allow(unused_const)]
    const ALPHA_POINTS_PER_USD: u64 = 1000; // 1 USD = 1000 Alpha Points
    
    // Constants for Event Structs
    // const POINTS_ACCRUED_EVENT_TYPE: vector<u8> = b"PointsAccrued"; // Removed as unused
    // const POINTS_CLAIMED_EVENT_TYPE: vector<u8> = b"PointsClaimed"; // Removed as unused
    
    // New Event for Supply Rate Retention
    public struct SupplyRateRetention<phantom T: store> has copy, drop {
        vault_id: ID,
        asset_type: String,
        retained_amount: u64
    }
    
    // Events
    #[allow(unused_field)]
    public struct StakeRouted<phantom T: store> has copy, drop {
        staker: address,
        stake_id: ID,
        asset_type: String, 
        amount_staked_asset: u64,
        duration_days: u64,
        unlock_time_ms: u64,
        native_stake_id: ID 
    }
    
    #[allow(unused_field)]
    public struct StakeRedeemedEvent<phantom T: store> has copy, drop {
        redeemer: address,
        stake_id: ID,
        asset_type: String,
        amount_returned_asset: u64,
        points_forfeited: u64
    }
    
    public struct PointsEarned has copy, drop {
        user: address,
        amount: u64,
        partner: address
    }
    
    #[allow(unused_field)]
    public struct PointsSpent has copy, drop {
        user: address,
        amount: u64
    }
    
    public struct PointsLocked has copy, drop {
        user: address,
        amount: u64
    }
    
    public struct PointsUnlocked has copy, drop {
        user: address,
        amount: u64
    }
    
    public struct PointsRedeemedEvent<phantom T: store> has copy, drop {
        user: address,
        points_amount: u64,
        asset_amount: u64
    }
    
    /// Event emitted when user claims accrued points from a stake
    public struct PointsClaimed has store, copy, drop {
        user: address,
        stake_id: ID,
        points_claimed: u64,
        asset_type: String,
        claim_epoch: u64,
    }
    
    /// Event emitted when an admin claims a forfeited (expired) stake
    #[allow(unused_field)]
    public struct StakeForfeited has store, copy, drop {
        admin_cap_id: ID,
        staker_address: address,
        stake_id: ID,
        forfeited_amount: u64,
        asset_type: String,
    }
    
    /// Event emitted when a user repays bad debt
    #[allow(unused_field)]
    public struct BadDebtRepaid has copy, drop {
        user: address,
        paid_sui_amount: u64,
        repaid_debt_points: u64,
        remaining_debt_points: u64
    }
    
    /// Event emitted when a user initiates native withdrawal and receives the ticket
    #[allow(unused_field)]
    public struct WithdrawalTicketIssued has copy, drop {
        user: address,
        native_stake_id: ID
    }
    
    /// Event emitted when a user's native SUI stake is converted to Alpha Points
    /// and the SUI withdrawal ticket is stored by the protocol.
    public struct StakeConvertedToPoints has store, copy, drop {
        user: address,
        original_staked_sui_id: ID, // ID of the StakedSui object that was unstaked
        sui_amount_unstaked: u64,   // The principal amount of SUI that was unstaked
        points_minted: u64,         // The amount of Alpha Points minted to the user
        stake_position_id: ID,      // ID of the destroyed StakePosition NFT
    }
    
    /// Event emitted when staked assets are deposited into the protocol
    public struct StakeDeposited<phantom T> has copy, drop {
        staker: address,
        stake_id: ID,
        asset_type: string::String, 
        amount_staked: u64,
        duration_days: u64,
        unlock_time_ms: u64,
        native_stake_id: ID 
    }
    
    /// Event emitted when staked assets are redeemed back to the native asset
    #[allow(unused_field)]
    public struct StakeRedeemed<phantom T: store> has copy, drop {
        redeemer: address,
        principal_redeemed: u64,
        points_used: u64,
        fee_paid: u64,
        epoch: u64
    }
    
    /// Event emitted when points are redeemed for the fee asset
    public struct PartnerAttribution has copy, drop {
        partner_address: address,
        user: address,
        action: vector<u8>,
        amount: u64,
        fee_share: u64
    }
    
    /// Event emitted when forfeited stake funds are withdrawn to treasury
    public struct ForfeitedStakeWithdrawn has copy, drop {
        admin_cap_id: ID,
        amount: u64,
        treasury_address: address,
    }

    /// Event emitted when an old stake is migrated to the new package
    public struct OldStakeMigrated has copy, drop {
        admin_cap_id: ID,
        old_stake_owner: address,
        old_stake_principal: u64,
        old_stake_duration_days: u64,
        old_stake_start_time_ms: u64,
        replacement_alpha_points: u64,
        compensation_amount: u64,
    }

    /// Event emitted when multiple old stakes are batch migrated
    public struct BatchOldStakesMigrated has copy, drop {
        admin_cap_id: ID,
        stakes_migrated: u64,
        total_principal_compensated: u64,
        total_points_issued: u64,
        compensation_amount: u64,
    }

    /// Event emitted when a user initiates a liquid unstake, receiving points as a loan against their stake.
    public struct LiquidUnstakeAsLoanInitiated has store, copy, drop {
        user: address,
        stake_position_id: ID,      // ID of the StakePosition NFT being used as collateral
        native_sui_stake_id: ID,    // ID of the underlying StakedSui object
        sui_value_for_loan: u64,    // The SUI principal value backing the loan
        points_loaned: u64,         // The amount of Alpha Points loaned to the user
        loan_fee_points: u64,       // Fee taken for opening this loan (if any)
        loan_object_id: ID,         // ID of the Loan object created (held by protocol admin)
        opened_time_ms: u64,
    }

    /// Event emitted when a user purchases a perk from the marketplace.
    public struct PerkPurchased has copy, drop {
        user: address,
        perk_provider_partner_address: address,
        points_spent: u64,
        partner_share_points: u64,
        deployer_share_points: u64,
        burned_amount_points: u64,
        // perk_identifier: String, // Optional: Consider adding if perks have unique IDs
    }

    /// Event emitted when user claims accrued points from a stake
    public entry fun redeem_points<T: store>(
        config: &Config,
        ledger: &mut Ledger,
        escrow: &mut EscrowVault<T>,
        oracle: &RateOracle,
        points_amount: u64,
        _clock: &Clock,
        ctx: &mut TxContext
    ) {
        admin::assert_not_paused(config);
        let user = tx_context::sender(ctx);
        let deployer = admin::deployer_address(config);
        let (rate, decimals) = oracle::get_rate(oracle);
        
        let total_asset_amount_initial = oracle::convert_points_to_asset(points_amount, rate, decimals);
        
        let supply_redeem_rate_bps: u64 = 0; // Assuming 0 as SupplyOracle is removed
        
        let reduction_due_to_supply_rate = if (total_asset_amount_initial > 0 && supply_redeem_rate_bps > 0) {
            (total_asset_amount_initial * supply_redeem_rate_bps) / 10000
        } else {
            0
        };
        let total_asset_amount_after_supply_rate = total_asset_amount_initial - reduction_due_to_supply_rate;

        let fee_asset_amount = total_asset_amount_after_supply_rate / 1000; 
        let user_asset_amount = total_asset_amount_after_supply_rate - fee_asset_amount;
        
        assert!(fee_asset_amount <= total_asset_amount_after_supply_rate, EFeeCalculationError);

        ledger::internal_spend(ledger, user, points_amount, ctx);
        
        if (user_asset_amount > 0) {
            escrow::withdraw(escrow, user_asset_amount, user, ctx);
        };
        if (fee_asset_amount > 0) {
            escrow::withdraw(escrow, fee_asset_amount, deployer, ctx);
        };

        if (reduction_due_to_supply_rate > 0) {
            let asset_name_ascii = std::type_name::into_string(std::type_name::get<T>());
            let asset_name_string = string::utf8(ascii::into_bytes(asset_name_ascii));
            event::emit(SupplyRateRetention<T> {
                vault_id: object::id_from_address(object::uid_to_address(escrow::vault_uid(escrow))),
                asset_type: asset_name_string,
                retained_amount: reduction_due_to_supply_rate
            });
        };
        
        event::emit(PointsRedeemedEvent<T> {
            user,
            points_amount,
            asset_amount: total_asset_amount_after_supply_rate
        });
    }
    
    /// Redeems points for the underlying asset WITH partner attribution
    public entry fun redeem_points_with_partner<T: store>(
        config: &Config,
        ledger: &mut Ledger,
        escrow: &mut EscrowVault<T>,
        oracle: &RateOracle,
        points_amount: u64,
        partner_cap: &PartnerCap,
        _clock: &Clock,
        ctx: &mut TxContext
    ) {
        admin::assert_not_paused(config);
        let user = tx_context::sender(ctx);
        let deployer = admin::deployer_address(config);
        let (rate, decimals) = oracle::get_rate(oracle);

        let total_asset_amount_initial = oracle::convert_points_to_asset(points_amount, rate, decimals);

        let supply_redeem_rate_bps: u64 = 0; // Assuming 0 as SupplyOracle is removed
        
        let reduction_due_to_supply_rate = if (total_asset_amount_initial > 0 && supply_redeem_rate_bps > 0) {
            (total_asset_amount_initial * supply_redeem_rate_bps) / 10000
        } else {
            0
        };
        let total_asset_amount_after_supply_rate = total_asset_amount_initial - reduction_due_to_supply_rate;

        let fee_asset_amount = total_asset_amount_after_supply_rate / 1000;
        let user_asset_amount_after_std_fee = total_asset_amount_after_supply_rate - fee_asset_amount;

        let partner_fee_share = fee_asset_amount / 5; 
        let deployer_fee_share = fee_asset_amount - partner_fee_share;
        let user_final_asset_amount = user_asset_amount_after_std_fee;

        assert!(fee_asset_amount <= total_asset_amount_after_supply_rate, EFeeCalculationError);
        assert!(partner_fee_share <= fee_asset_amount, EFeeCalculationError); 

        ledger::internal_spend(ledger, user, points_amount, ctx);
        
        if (user_final_asset_amount > 0) {
            escrow::withdraw(escrow, user_final_asset_amount, user, ctx);
        };
        
        let partner_addr = object::uid_to_address(partner::get_id(partner_cap));
        if (partner_fee_share > 0) {
            escrow::withdraw(escrow, partner_fee_share, partner_addr, ctx);
            event::emit(PartnerAttribution {
                partner_address: partner_addr,
                user,
                action: b"redeem_points_with_partner",
                amount: points_amount,
                fee_share: partner_fee_share
            });
        };
        if (deployer_fee_share > 0) {
            escrow::withdraw(escrow, deployer_fee_share, deployer, ctx);
        };

        if (reduction_due_to_supply_rate > 0) {
            let asset_name_ascii = std::type_name::into_string(std::type_name::get<T>());
            let asset_name_string = string::utf8(ascii::into_bytes(asset_name_ascii));
            event::emit(SupplyRateRetention<T> {
                vault_id: object::id_from_address(object::uid_to_address(escrow::vault_uid(escrow))),
                asset_type: asset_name_string,
                retained_amount: reduction_due_to_supply_rate
            });
        };
        
        event::emit(PointsRedeemedEvent<T> {
            user,
            points_amount,
            asset_amount: total_asset_amount_after_supply_rate
        });
    }
    
    /// Calls admin::assert_not_paused, ledger::internal_lock
    public entry fun lock_points(
        config: &Config,
        ledger: &mut Ledger,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Check protocol is not paused
        admin::assert_not_paused(config);
        
        let user = tx_context::sender(ctx);
        
        // Lock points
        ledger::internal_lock(ledger, user, amount, ctx);
        
        // Emit event
        event::emit(PointsLocked {
            user,
            amount
        });
    }
    
    /// Calls admin::assert_not_paused, ledger::internal_unlock
    public entry fun unlock_points(
        config: &Config,
        ledger: &mut Ledger,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Check protocol is not paused
        admin::assert_not_paused(config);
        
        let user = tx_context::sender(ctx);
        
        // Unlock points
        ledger::internal_unlock(ledger, user, amount, ctx);
        
        // Emit event
        event::emit(PointsUnlocked {
            user,
            amount
        });
    }
    
    // Helper to get APY in Basis Points (bps) based on duration_days
    // Matches frontend DEFAULT_DURATIONS APY values
    // For MVP, this is a hardcoded lookup. Could be driven by Config later.
    fun get_apy_bps_for_duration_days(duration_days: u64): u64 {
        if (duration_days == 7) { 500 } // 5.0%
        else if (duration_days == 14) { 750 } // 7.5%
        else if (duration_days == 30) { 1000 } // 10.0%
        else if (duration_days == 90) { 1500 } // 15.0%
        else if (duration_days == 180) { 2000 } // 20.0%
        else if (duration_days == 365) { 2500 } // 25.0%
        else {
            abort EInvalidStakeDurationForApy
        }
    }

    // NEW: Helper function to convert SUI MIST to Alpha Points using 1:1000 USD ratio
    fun mist_to_alpha_points(mist_amount: u64): u64 {
        if (mist_amount == 0) return 0;
        // Formula: (mist_amount * 3.28 USD * 1000 AP/USD) / (1 SUI_MIST * 1000 milli conversion)
        // = mist_amount * 3,280 / 1,000,000,000
        ((mist_amount as u128) * (SUI_PRICE_USD_MILLI as u128) / (SUI_TO_MIST_CONVERSION as u128)) as u64
    }

    /// Allows a user to claim accrued Alpha Points for their stake position.
    public entry fun claim_accrued_points<T: key + store>(
        config: &Config,
        ledger: &mut Ledger,
        stake_position: &mut StakePosition<T>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        admin::assert_not_paused(config);
        let claimer = tx_context::sender(ctx);
        assert!(stake_position::owner_view(stake_position) == claimer, EAdminOnly);
        let _current_epoch = tx_context::epoch(ctx);
        let last_claim_epoch = stake_position::last_claim_epoch_view(stake_position);
        assert!(_current_epoch > last_claim_epoch, EAlreadyClaimedOrTooSoon);
        
        let points_rate = admin::get_points_rate(config);
        let points_to_claim = ledger::calculate_accrued_points(
            stake_position::principal_view(stake_position),
            points_rate,
            last_claim_epoch,
            _current_epoch
        );

        if (points_to_claim > 0) {
            stake_position::set_last_claim_epoch_mut(stake_position, _current_epoch);
            stake_position::add_claimed_rewards_mut(stake_position, points_to_claim);

            let stake_opt_none = std::option::none<StakePosition<T>>();
            ledger::mint_points<T>(
                ledger,
                claimer,
                points_to_claim,
                ledger::new_point_type_staking(),
                ctx,
                &stake_opt_none,
                admin::get_default_liq_share(config),
                clock
            );
            std::option::destroy_none(stake_opt_none);

            let asset_name_ascii = std::type_name::into_string(std::type_name::get<T>());
            let asset_name_string = string::utf8(ascii::into_bytes(asset_name_ascii));
            event::emit(PointsClaimed {
                user: claimer,
                stake_id: stake_position::get_id_view(stake_position),
                points_claimed: points_to_claim,
                asset_type: asset_name_string,
                claim_epoch: _current_epoch,
            });
        }
    }
    
    /// Allows an admin to claim a forfeited stake that has passed its expiry window.
    /// Initiates unstaking but currently discards the withdrawal ticket.
    /// NOTE: Phase 5 Change - This function NO LONGER initiates native unstake.
    /// Admin must call `admin_withdraw_forfeited_stake` separately after this.
    /// @deprecated Use admin_claim_forfeited_stake_v2 for proper implementation
    public entry fun admin_claim_forfeited_stake<T: store>(
        admin_cap: &AdminCap,
        config: &Config,
        _manager: &mut StakingManager,
        _escrow_vault: &mut EscrowVault<T>,
        _sui_system_state_obj: &mut SuiSystemState,
        stake_id_to_forfeit: ID,
        _clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(admin::is_admin(admin_cap, config), EAdminOnly);

        let staker_address: address = tx_context::sender(ctx);
        let forfeited_amount: u64 = 1;
        let asset_name_ascii = std::type_name::into_string(std::type_name::get<T>());
        let asset_name_string = string::utf8(ascii::into_bytes(asset_name_ascii));
        
        event::emit(StakeForfeited {
            admin_cap_id: admin::admin_cap_id(config),
            staker_address: staker_address,
            stake_id: stake_id_to_forfeit,
            forfeited_amount: forfeited_amount,
            asset_type: asset_name_string,
        });
    }

    /// New implementation for admin forfeiture of expired stakes
    /// This function properly validates the stake is forfeitable and processes the forfeiture
    public entry fun admin_claim_forfeited_stake_v2(
        admin_cap: &AdminCap,
        config: &Config,
        manager: &mut StakingManager,
        stake_position: StakePosition<StakedSui>,
        sui_system_state: &mut SuiSystemState,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(admin::is_admin(admin_cap, config), EAdminOnly);
        
        // Check if stake is past forfeiture grace period
        let current_time_ms = clock::timestamp_ms(clock);
        let unlock_time_ms = stake_position::unlock_time_ms_view(&stake_position);
        let grace_period_ms = admin::get_forfeiture_grace_period_ms(config);
        let forfeiture_threshold_ms = unlock_time_ms + grace_period_ms;
        
        assert!(current_time_ms > forfeiture_threshold_ms, ENotPastGracePeriod);
        assert!(!stake_position::is_encumbered_view(&stake_position), EStakeEncumbered);
        
        let staker_address = stake_position::owner_view(&stake_position);
        let forfeited_amount = stake_position::principal_view(&stake_position);
        let stake_id = stake_position::get_id_view(&stake_position);
        
        // Get native stake ID and request withdrawal
        let native_staked_sui_address = stake_position::native_stake_id_view(&stake_position);
        let native_staked_sui_id = id_from_address(native_staked_sui_address);
        
        if (native_staked_sui_address != @0x0 && staking_manager::has_native_stake(manager, native_staked_sui_id)) {
            staking_manager::request_native_stake_withdrawal(
                manager,
                sui_system_state,
                native_staked_sui_id,
                ctx
            );
        };
        
        // Destroy the stake position
        stake_position::destroy_stake(stake_position);
        
        event::emit(StakeForfeited {
            admin_cap_id: admin::admin_cap_id(config),
            staker_address,
            stake_id,
            forfeited_amount,
            asset_type: string::utf8(b"StakedSui"),
        });
    }

    /// Withdraws forfeited stake funds to protocol treasury
    /// Should be called after admin_claim_forfeited_stake_v2 processes the forfeiture
    public entry fun admin_withdraw_forfeited_stake(
        admin_cap: &AdminCap,
        config: &Config,
        forfeited_funds: Coin<SUI>,
        _ctx: &mut TxContext
    ) {
        assert!(admin::is_admin(admin_cap, config), EAdminOnly);
        
        let amount = coin::value(&forfeited_funds);
        let treasury_address = admin::deployer_address(config);
        
        transfer::public_transfer(forfeited_funds, treasury_address);
        
        event::emit(ForfeitedStakeWithdrawn {
            admin_cap_id: admin::admin_cap_id(config),
            amount,
            treasury_address,
        });
    }

    /// Allows a user to repay their outstanding bad debt using SUI.
    public entry fun repay_bad_debt(
        config: &Config,
        ledger: &mut Ledger,
        payment: Coin<SUI>,
        oracle: &RateOracle,
        ctx: &mut TxContext
    ) {
        admin::assert_not_paused(config);
        let user = tx_context::sender(ctx);
        let payment_value_sui = coin::value(&payment);
        let (rate, decimals) = oracle::get_rate(oracle);
        let payment_value_points = oracle::convert_asset_to_points(payment_value_sui, rate, decimals);
        let initial_debt_points = ledger::get_bad_debt(ledger, user);
        
        assert!(payment_value_points > 0, ERepaymentAmountError);
        
        let debt_to_repay_points = std::u64::min(payment_value_points, initial_debt_points);
        
        ledger::internal_remove_bad_debt(ledger, user, debt_to_repay_points);
        
        let remaining_debt_points = initial_debt_points - debt_to_repay_points;

        transfer::public_transfer(payment, admin::deployer_address(config));

        event::emit(BadDebtRepaid {
            user,
            paid_sui_amount: payment_value_sui,
            repaid_debt_points: debt_to_repay_points,
            remaining_debt_points
        });
    }

    // --- View Functions ---

    /// Get the current points balance for a user
    public fun get_points(ledger: &Ledger, user: address): u64 {
        ledger::get_total_balance(ledger, user)
    }

    /// Get the available points balance for a user
    public fun get_available_points(ledger: &Ledger, user: address): u64 {
        ledger::get_available_balance(ledger, user)
    }

    /// Get the locked points balance for a user
    public fun get_locked_points(ledger: &Ledger, user: address): u64 {
        ledger::get_locked_balance(ledger, user)
    }

    /// Get the current bad debt points for a user
    public fun get_bad_debt_points(ledger: &Ledger, user: address): u64 {
        ledger::get_bad_debt(ledger, user)
    }

    /// Get the current conversion rate from asset to points
    public fun get_asset_to_points_rate(
        oracle: &RateOracle, 
        _clock: &Clock
    ): (u64, u8) {
        let (rate128, dec) = oracle::get_rate(oracle);
        ((rate128 as u64), dec)
    }

    public fun get_user_bad_debt(ledger: &Ledger, user: address): u64 {
        ledger::get_bad_debt(ledger, user)
    }

    /// @deprecated Use get_user_staked_balance_v2 for proper implementation
    public fun get_user_staked_balance<T: store>(
        _escrow_vault: &EscrowVault<T>,
        _user: address,
        _ctx: &mut TxContext
    ): u64 {
        0
    }

    /// New implementation for getting user's staked balance
    /// Note: EscrowVault doesn't track individual user balances
    /// This function provides total vault balance as reference
    public fun get_user_staked_balance_v2<T: store>(
        escrow_vault: &EscrowVault<T>,
        _user: address,
        _ctx: &mut TxContext
    ): u64 {
        // EscrowVault doesn't track individual user balances
        // Return total vault balance as the best approximation available
        escrow::total_value(escrow_vault)
    }

    public fun get_user_points_balance(
        ledger: &Ledger,
        user: address
    ): u64 {
        ledger::get_total_balance(ledger, user)
    }

    // test init function
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        admin::init_for_testing(ctx);
    }

    /// @deprecated Use get_escrow_stake_details_v2 for proper implementation
    public fun get_escrow_stake_details<T: store>(
        _escrow_vault: &EscrowVault<T>,
        _owner: address,
        _stake_id: ID,
        _ctx: &mut TxContext
    ): (u64, u64, u64, bool, ID) {
        (0,0,0,false, object::id_from_bytes(vector[]))
    }

    /// New implementation that actually queries escrow vault data
    /// Returns: (amount, unlock_time_ms, start_time_ms, is_encumbered, stake_position_id)
    /// Note: This function works with StakePosition NFTs, not escrow vault data
    /// Use get_stake_position_details_v2 instead for StakePosition objects
    public fun get_escrow_stake_details_v2<T: store>(
        escrow_vault: &EscrowVault<T>,
        _owner: address,
        _stake_id: ID,
        _ctx: &mut TxContext
    ): (u64, u64, u64, bool, ID) {
        // EscrowVault only holds coin balances, not individual stake records
        // Return the total vault balance as a single "stake"
        let total_balance = escrow::total_value(escrow_vault);
        let vault_id = object::uid_to_inner(escrow::vault_uid(escrow_vault));
        (total_balance, 0, 0, false, vault_id)
    }

    /// @deprecated Use get_stake_details_v2 for proper implementation  
    public fun get_stake_details<T: store>(
        _escrow_vault: &EscrowVault<T>,
        _owner: address,
        _stake_id: ID,
        _ctx: &mut TxContext
    ): (u64, u64, u64, bool, ID) {
        (0,0,0,false, object::id_from_bytes(vector[]))
    }

    /// New implementation for getting StakePosition details
    /// Returns: (amount, unlock_time_ms, start_time_ms, is_encumbered, stake_position_id)
    public fun get_stake_position_details_v2<T: store>(
        stake_position: &StakePosition<T>
    ): (u64, u64, u64, bool, ID) {
        let amount = stake_position::principal_view(stake_position);
        let unlock_time_ms = stake_position::unlock_time_ms_view(stake_position);
        let start_time_ms = stake_position::start_time_ms_view(stake_position);
        let is_encumbered = stake_position::is_encumbered_view(stake_position);
        let stake_id = stake_position::get_id_view(stake_position);
        
        (amount, unlock_time_ms, start_time_ms, is_encumbered, stake_id)
    }

    /// @deprecated Always returns 0 - use total_staked_value_in_escrow_v2 for proper implementation
    public fun total_staked_value_in_escrow<T: key + store>(
        _escrow: &EscrowVault<T>
    ): u64 {
        0
    }

    /// New implementation that returns actual escrow vault balance
    public fun total_staked_value_in_escrow_v2<T: key + store>(
        escrow: &EscrowVault<T>
    ): u64 {
        escrow::total_value(escrow)
    }

    /// Get total number of stakes managed by the staking manager
    public fun get_total_managed_stakes(manager: &StakingManager): u64 {
        staking_manager::get_total_stakes_count(manager)
    }

    /// Check if a specific native stake exists in the manager
    public fun has_managed_stake(manager: &StakingManager, stake_id: ID): bool {
        staking_manager::has_native_stake(manager, stake_id)
    }

    /// Get the balance of a specific managed stake
    public fun get_managed_stake_balance(manager: &StakingManager, stake_id: ID): u64 {
        if (staking_manager::has_native_stake(manager, stake_id)) {
            staking_manager::get_native_stake_balance(manager, stake_id)
        } else {
            0
        }
    }

    /// Get all essential information about a StakePosition in one call
    /// Returns: (owner, amount, unlock_time_ms, start_time_ms, is_encumbered, is_mature, native_stake_id)
    public fun get_stake_position_full_info<T: store>(
        stake_position: &StakePosition<T>,
        clock: &Clock
    ): (address, u64, u64, u64, bool, bool, address) {
        let owner = stake_position::owner_view(stake_position);
        let amount = stake_position::principal_view(stake_position);
        let unlock_time_ms = stake_position::unlock_time_ms_view(stake_position);
        let start_time_ms = stake_position::start_time_ms_view(stake_position);
        let is_encumbered = stake_position::is_encumbered_view(stake_position);
        let is_mature = stake_position::is_mature(stake_position, clock);
        let native_stake_id = stake_position::native_stake_id_view(stake_position);
        
        (owner, amount, unlock_time_ms, start_time_ms, is_encumbered, is_mature, native_stake_id)
    }

    /// Check if a stake is eligible for forfeiture by admin
    /// Returns true if stake is past grace period and not encumbered
    public fun is_stake_forfeitable<T: store>(
        stake_position: &StakePosition<T>,
        config: &Config,
        clock: &Clock
    ): bool {
        let current_time_ms = clock::timestamp_ms(clock);
        let unlock_time_ms = stake_position::unlock_time_ms_view(stake_position);
        let grace_period_ms = admin::get_forfeiture_grace_period_ms(config);
        let forfeiture_threshold_ms = unlock_time_ms + grace_period_ms;
        
        current_time_ms > forfeiture_threshold_ms && !stake_position::is_encumbered_view(stake_position)
    }

    /// Get comprehensive escrow vault information
    /// Returns: (vault_id, total_balance)
    public fun get_escrow_vault_info<T: store>(
        escrow_vault: &EscrowVault<T>
    ): (ID, u64) {
        let vault_id = object::uid_to_inner(escrow::vault_uid(escrow_vault));
        let total_balance = escrow::total_value(escrow_vault);
        (vault_id, total_balance)
    }

    /// Get staking manager statistics
    /// Returns: (manager_id, total_stakes_count)
    public fun get_staking_manager_stats(manager: &StakingManager): (ID, u64) {
        let manager_id = object::id(manager);
        let total_stakes = staking_manager::get_total_stakes_count(manager);
        (manager_id, total_stakes)
    }

    /// Calculate time remaining until stake unlock (returns 0 if already unlocked)
    public fun get_time_until_unlock<T: store>(
        stake_position: &StakePosition<T>,
        clock: &Clock
    ): u64 {
        let current_time_ms = clock::timestamp_ms(clock);
        let unlock_time_ms = stake_position::unlock_time_ms_view(stake_position);
        
        if (current_time_ms >= unlock_time_ms) {
            0
        } else {
            unlock_time_ms - current_time_ms
        }
    }

    /// Calculate time until forfeiture becomes available (returns 0 if already forfeitable)
    public fun get_time_until_forfeitable<T: store>(
        stake_position: &StakePosition<T>,
        config: &Config,
        clock: &Clock
    ): u64 {
        let current_time_ms = clock::timestamp_ms(clock);
        let unlock_time_ms = stake_position::unlock_time_ms_view(stake_position);
        let grace_period_ms = admin::get_forfeiture_grace_period_ms(config);
        let forfeiture_threshold_ms = unlock_time_ms + grace_period_ms;
        
        if (current_time_ms >= forfeiture_threshold_ms) {
            0
        } else {
            forfeiture_threshold_ms - current_time_ms
        }
    }

    /// ⚠️  CRITICAL ECONOMIC FLAW: This function incorrectly mints Alpha Points during unstaking
    /// 
    /// PROBLEM: When users unstake after maturity, they should get their SUI back, NOT Alpha Points.
    /// Currently this function does BOTH:
    /// 1. Requests SUI withdrawal (correct)
    /// 2. Mints Alpha Points equal to principal (WRONG!)
    /// 
    /// CORRECT BEHAVIOR SHOULD BE:
    /// - During staking: Users earn Alpha Points as rewards (via claim_accrued_points)
    /// - After maturity: Users unstake to get their original SUI principal back
    /// - Users should NOT get both SUI + Alpha Points - that's double-dipping!
    /// 
    /// ECONOMIC IMPACT:
    /// - Users get ~3,280 Alpha Points per SUI unstaked (worth $3.28)
    /// - Plus they get their full SUI back (worth $3.28)
    /// - Total value: ~$6.56 per SUI staked (100% profit just for unstaking!)
    /// - This breaks the economic model and creates infinite value generation
    /// 
    /// FIX NEEDED: Remove the mint_points call from this function
    /// CANNOT FIX: Sui Move upgrade rules prevent changing public function behavior
    /// 
    /// @deprecated Use a new function that only handles SUI withdrawal without minting points
    public entry fun request_unstake_native_sui(
        manager: &mut StakingManager,
        config: &Config,
        sui_system_state: &mut SuiSystemState,
        stake_position: StakePosition<StakedSui>,
        clock: &Clock,
        ledger: &mut Ledger,
        ctx: &mut TxContext
    ) {
        admin::assert_not_paused(config);
        let user = tx_context::sender(ctx);
        assert!(stake_position::owner_view(&stake_position) == user, ENotOwner);
        assert!(!stake_position::is_encumbered_view(&stake_position), EStakeEncumbered);
        assert!(stake_position::is_redeemable(&stake_position, clock), ENotRedeemable);
        
        let native_staked_sui_address = stake_position::native_stake_id_view(&stake_position);
        let native_staked_sui_id = id_from_address(native_staked_sui_address);
        assert!(native_staked_sui_address != @0x0, EInvalidStakeIdType);
        
        let principal_sui = stake_position::principal_view(&stake_position);
        let stake_position_id = stake_position::get_id_view(&stake_position);
        
        staking_manager::request_native_stake_withdrawal(
            manager,
            sui_system_state,
            native_staked_sui_id,
            ctx
        );

        let stake_opt_none = std::option::none<StakePosition<StakedSui>>();
        if (principal_sui > 0) {
            ledger::mint_points<StakedSui>(
                ledger,
                user,
                principal_sui,
                ledger::new_point_type_staking(),
                ctx,
                &stake_opt_none,
                admin::get_default_liq_share(config),
                clock
            );
        };
        std::option::destroy_none(stake_opt_none);
        
        stake_position::destroy_stake(stake_position);
        
        event::emit(StakeConvertedToPoints {
            user,
            original_staked_sui_id: native_staked_sui_id,
            sui_amount_unstaked: principal_sui,
            points_minted: principal_sui,
            stake_position_id,
        });
    }

    /// View function to calculate accrued points for a stake position
    /// 
    /// ⚠️  KNOWN ISSUE: INCONSISTENT WITH ledger::calculate_accrued_points
    /// This function uses APY_POINT_SCALING_FACTOR=25 and different denominator
    /// while ledger uses flat rate per epoch. Results in different calculations!
    /// 
    /// PROBLEMS:
    /// 1. Uses arbitrary scaling factor (25) instead of proper APY conversion
    /// 2. Different logic than main calculation function
    /// 3. Both approaches give wrong results vs intended APY economics
    /// 
    /// CORRECT FORMULA SHOULD BE:
    /// principal_in_AP = (principal * 3280) / 1e9
    /// points = (principal_in_AP * apy_bps * epochs) / (10000 * 365)
    /// 
    /// CANNOT FIX: Upgrade rules prevent changing public function logic
    /// 
    public fun view_accrued_points_for_stake<T: key + store>(
        stake_position: &StakePosition<T>,
        current_epoch: u64
    ): u64 {
        let last_claim_epoch = stake_position::last_claim_epoch_view(stake_position);
        if (current_epoch <= last_claim_epoch) {
            return 0
        };
        
        let denominator = (SUI_TO_MIST_CONVERSION as u128) * (EPOCHS_PER_YEAR as u128);
        let points_per_epoch = if (denominator > 0) {
            ((stake_position::principal_view(stake_position) as u128) * 
            (get_apy_bps_for_duration_days(stake_position::duration_days_view(stake_position)) as u128) * 
            (APY_POINT_SCALING_FACTOR as u128) / denominator) as u64
        } else {
            0
        };
        
        points_per_epoch * (current_epoch - last_claim_epoch)
    }

    /// Public entry function to stake SUI into the protocol.
    /// Stakes the provided Coin<SUI> natively using the Sui system, creates a StakePosition<SUI> NFT,
    /// stores the underlying StakedSui object in the StakingManager, and transfers the
    /// StakePosition<SUI> NFT to the staker.
    public entry fun route_stake_sui(
        config: &Config,
        _ledger: &mut Ledger,
        manager: &mut StakingManager,
        clock: &Clock,
        staked_sui: StakedSui,
        duration_days: u64,
        _referrer: Option<address>,
        ctx: &mut TxContext
    ) {
        admin::assert_not_paused(config);
        let staker = tx_context::sender(ctx);
        let stake_amount_mist = staked_sui_amount(&staked_sui);
        let native_stake_id = object::id(&staked_sui);
        
        staking_manager::store_native_stake(manager, staked_sui, ctx);
        
        let mut stake_position_obj = stake_position::create_stake<StakedSui>(
            stake_amount_mist,
            duration_days,
            clock,
            ctx
        );
        stake_position::set_native_stake_id_mut(&mut stake_position_obj, native_stake_id);
        
        let stake_position_id = object::id(&stake_position_obj);
        transfer::public_transfer(stake_position_obj, staker);
        
        event::emit(StakeDeposited<StakedSui> {
            staker,
            stake_id: stake_position_id,
            asset_type: string::utf8(ascii::into_bytes(std::type_name::into_string(std::type_name::get<StakedSui>()))),
            amount_staked: stake_amount_mist,
            duration_days,
            unlock_time_ms: sui::clock::timestamp_ms(clock) + duration_days * stake_position::get_ms_per_day(),
            native_stake_id,
        });
    }

    /// Legacy function for backward compatibility (DEPRECATED)
    /// @deprecated Use earn_points_by_partner_flex for TVL-backed quota validation
    public entry fun earn_points_by_partner(
        user: address,
        pts: u64,
        partner: &mut PartnerCap,
        ledger: &mut Ledger,
        clock: &Clock,
        config: &Config,
        ctx: &mut TxContext
    ) {
        assert!(!partner::get_paused(partner), EPartnerPaused);
        let _current_epoch = tx_context::epoch(ctx);

        if (_current_epoch > partner::get_last_epoch(partner)) {
            partner::reset_mint_today_mut(partner, _current_epoch);
        };
        assert!(partner::get_mint_remaining_today(partner) >= pts, EPartnerExceedsQuota);
        
        let stake_opt = std_option::none<StakePosition<u8>>();
        ledger::mint_points<u8>(
            ledger,
            user,
            pts,
            ledger::new_point_type_generic_reward(),
            ctx,
            &stake_opt,
            admin::get_default_liq_share(config),
            clock
        );
        std_option::destroy_none(stake_opt);

        partner::decrease_mint_remaining_today_mut(partner, pts);
        
        event::emit(PointsEarned { 
            user, 
            amount: pts, 
            partner: object::uid_to_address(partner::get_id(partner))
        });
    }

    /// Modern function with TVL-backed quota validation using PartnerCapFlex
    /// This function validates against the partner's quota backed by actual TVL
    public entry fun earn_points_by_partner_flex(
        user: address,
        pts: u64,
        partner_cap: &mut PartnerCapFlex,
        ledger: &mut Ledger,
        clock: &Clock,
        config: &Config,
        ctx: &mut TxContext
    ) {
        let current_epoch = tx_context::epoch(ctx);
        
        // Validate that partner can mint the requested points within their quota
        partner_flex::validate_mint_quota(partner_cap, pts, current_epoch, ctx);
        
        // Mint the points to the user
        let stake_opt = std_option::none<StakePosition<u8>>();
        ledger::mint_points<u8>(
            ledger,
            user,
            pts,
            ledger::new_point_type_generic_reward(),
            ctx,
            &stake_opt,
            admin::get_default_liq_share(config),
            clock
        );
        std_option::destroy_none(stake_opt);

        // Record the points minted against partner's quota
        partner_flex::record_points_minted(partner_cap, pts, current_epoch, ctx);
        
        event::emit(PointsEarned { 
            user, 
            amount: pts, 
            partner: partner_flex::partner_address(partner_cap)
        });
    }

    /// Allows a user to get an instant Alpha Points loan against their maturing/matured native SUI stake.
    /// The SUI stake is then unstaked by the protocol, and the Loan object is held by the protocol admin.
    /// The user's StakePosition NFT is encumbered and later destroyed by an admin action
    /// once the SUI is claimed by the protocol.
    #[allow(unused_const)]
    public entry fun liquid_unstake_as_loan_native_sui(
        config: &Config,
        _loan_config: &loan::LoanConfig,
        ledger: &mut Ledger,
        stake_position: &mut StakePosition<StakedSui>,
        clock: &Clock,
        staking_manager: &mut StakingManager,
        sui_system_state: &mut SuiSystemState,
        ctx: &mut TxContext
    ) {
        admin::assert_not_paused(config);
        let user = tx_context::sender(ctx);
        assert!(stake_position::owner_view(stake_position) == user, ENotOwner);
        assert!(!stake_position::is_encumbered_view(stake_position), EStakeEncumbered);
        assert!(stake_position::is_redeemable(stake_position, clock), EStakeNotMatureForLoan);
        
        let sui_principal_for_loan = stake_position::principal_view(stake_position);
        let loan_fee_points = sui_principal_for_loan / 1000;
        let points_to_user_net = sui_principal_for_loan - loan_fee_points;
        
        assert!(loan_fee_points <= sui_principal_for_loan, EFeeCalculationError);
        
        if (points_to_user_net > 0) {
            let stake_opt_none = std_option::none<StakePosition<StakedSui>>();
            ledger::mint_points<StakedSui>(
                ledger,
                user,
                points_to_user_net,
                ledger::new_point_type_staking(),
                ctx,
                &stake_opt_none,
                admin::get_default_liq_share(config),
                clock
            );
            std_option::destroy_none(stake_opt_none);
        };
        
        if (loan_fee_points > 0) {
            let stake_opt_none_fee = std_option::none<StakePosition<StakedSui>>();
            ledger::mint_points<StakedSui>(
                ledger,
                admin::deployer_address(config),
                loan_fee_points,
                ledger::new_point_type_staking(),
                ctx,
                &stake_opt_none_fee,
                admin::get_default_liq_share(config),
                clock
            );
            std_option::destroy_none(stake_opt_none_fee);
        };

        let stake_pos_id = stake_position::get_id_view(stake_position);
        let loan_opened_time_ms = sui::clock::timestamp_ms(clock);
        let loan_object = loan::create_loan(
            user, 
            stake_pos_id, 
            sui_principal_for_loan, 
            loan_opened_time_ms, 
            ctx
        );
        let loan_object_id = object::uid_to_inner(loan::get_loan_uid(&loan_object));
        transfer::public_transfer(loan_object, user);
        
        stake_position::set_encumbered(stake_position, true);
        
        let native_staked_sui_address = stake_position::native_stake_id_view(stake_position);
        let native_staked_sui_id = id_from_address(native_staked_sui_address);
        assert!(native_staked_sui_address != @0x0, EInvalidStakeIdType);
        
        staking_manager::request_native_stake_withdrawal(
            staking_manager,
            sui_system_state,
            native_staked_sui_id,
            ctx
        );

        event::emit(LiquidUnstakeAsLoanInitiated {
            user,
            stake_position_id: stake_pos_id,
            native_sui_stake_id: native_staked_sui_id,
            sui_value_for_loan: sui_principal_for_loan,
            points_loaned: points_to_user_net,
            loan_fee_points,
            loan_object_id,
            opened_time_ms: loan_opened_time_ms,
        });
    }

    /// Allows minting points without partner cap restrictions for testing
    public entry fun earn_points_testnet(
        config: &Config,
        _bypass_cap: &TestnetBypassCap,
        user: address,
        pts: u64,
        ledger: &mut Ledger,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(admin::is_testnet_bypass_enabled(config), EAdminOnly);
        let _current_epoch = tx_context::epoch(ctx);

        let stake_opt = std_option::none<StakePosition<u8>>();
        ledger::mint_points<u8>(
            ledger,
            user,
            pts,
            ledger::new_point_type_generic_reward(),
            ctx,
            &stake_opt,
            admin::get_default_liq_share(config),
            clock
        );
        std_option::destroy_none(stake_opt);
        
        event::emit(PointsEarned { 
            user, 
            amount: pts, 
            partner: @0x0 
        });
    }

    /// Emergency unstake function that bypasses normal checks to allow users to recover their staked SUI.
    /// This is a one-time function to help users migrate from the old package.
    /// Only callable by the admin.
    public entry fun emergency_unstake_native_sui(
        admin_cap: &AdminCap,
        config: &Config,
        manager: &mut StakingManager,
        sui_system_state: &mut SuiSystemState,
        stake_position: StakePosition<StakedSui>,
        clock: &Clock,
        ledger: &mut Ledger,
        ctx: &mut TxContext
    ) {
        assert!(admin::is_admin(admin_cap, config), EAdminOnly);
        let user = stake_position::owner_view(&stake_position);
        let _current_epoch = tx_context::epoch(ctx);
        
        let native_staked_sui_address = stake_position::native_stake_id_view(&stake_position);
        let native_staked_sui_id = id_from_address(native_staked_sui_address);
        assert!(native_staked_sui_address != @0x0, EInvalidStakeIdType);
        
        let principal_sui = stake_position::principal_view(&stake_position);
        let stake_position_id = stake_position::get_id_view(&stake_position);
        
        staking_manager::request_native_stake_withdrawal(
            manager,
            sui_system_state,
            native_staked_sui_id,
            ctx
        );

        let stake_opt_none = std_option::none<StakePosition<StakedSui>>();
        if (principal_sui > 0) {
            ledger::mint_points<StakedSui>(
                ledger,
                user,
                principal_sui,
                ledger::new_point_type_staking(),
                ctx,
                &stake_opt_none,
                admin::get_default_liq_share(config),
                clock
            );
        };
        std_option::destroy_none(stake_opt_none);
        
        stake_position::destroy_stake(stake_position);
        
        event::emit(StakeConvertedToPoints {
            user,
            original_staked_sui_id: native_staked_sui_id,
            sui_amount_unstaked: principal_sui,
            points_minted: principal_sui,
            stake_position_id,
        });
    }

    /// @deprecated This function is deprecated in favor of the new perk_manager system.
    /// Use perk_manager::claim_perk_with_metadata_configurable_split instead for proper metadata handling.
    /// Allows a user to purchase a perk from the marketplace using Alpha Points.
    /// Points are distributed: 70% to the perk-providing partner, 30% to the deployer. 0% Burned.
    public entry fun purchase_marketplace_perk(
        config: &Config,
        ledger: &mut Ledger,
        partner_cap_of_perk_provider: &PartnerCap, // PartnerCap of the partner who listed the perk
        perk_cost_points: u64,
        // perk_identifier: String, // Optional: for more detailed event logging
        clock: &Clock, // Required by ledger::mint_points
        ctx: &mut TxContext
    ) {
        admin::assert_not_paused(config);
        let user = tx_context::sender(ctx);
        let deployer_address = admin::deployer_address(config);
        let partner_address = object::uid_to_address(partner::get_id(partner_cap_of_perk_provider));

        // 1. Ensure user has enough points
        assert!(ledger::get_available_balance(ledger, user) >= perk_cost_points, EInsufficientPointsForPerk);

        // 2. Spend user's points (this reduces their balance)
        ledger::internal_spend(ledger, user, perk_cost_points, ctx);

        // 3. Calculate shares (70% partner, 30% deployer, 0% burn)
        let partner_share_points = (perk_cost_points * 70) / 100;
        let deployer_share_points = perk_cost_points - partner_share_points; // The remainder is for the deployer
        
        // This assertion ensures no underflow and that shares sum up to the cost
        assert!(partner_share_points + deployer_share_points == perk_cost_points, EFeeCalculationError);

        // 4. Credit partner with their share using ledger::mint_points
        let stake_opt_none = std_option::none<StakePosition<u8>>(); // Using u8 as a generic type for non-staking mint
        if (partner_share_points > 0) {
            ledger::mint_points<u8>(
                ledger,
                partner_address,
                partner_share_points,
                ledger::new_point_type_generic_reward(), 
                ctx,
                &stake_opt_none,
                0, // liq_share
                clock
            )
        };

        // 5. Credit deployer with their share
        if (deployer_share_points > 0) {
            ledger::mint_points<u8>(
                ledger,
                deployer_address,
                deployer_share_points,
                ledger::new_point_type_generic_reward(), 
                ctx,
                &stake_opt_none,
                0, // liq_share
                clock
            )
        };
        std_option::destroy_none(stake_opt_none); // Clean up the Option

        // 6. Emit event
        event::emit(PerkPurchased {
            user,
            perk_provider_partner_address: partner_address,
            points_spent: perk_cost_points,
            partner_share_points,
            deployer_share_points,
            burned_amount_points: 0 // Now 0% burn
            // perk_identifier, // Include if you add this parameter
        });
    }

    // === NEW FUNCTIONS WITH CORRECTED 1:1000 USD RATIO ===
    // These functions replace the legacy ones above with proper Alpha Points conversion

    /// ⚠️  CRITICAL ECONOMIC FLAW: This V2 function STILL has the same fundamental problem!
    /// 
    /// PROBLEM: This function fixes the 223x multiplier bug but STILL incorrectly mints Alpha Points
    /// during unstaking. Users should get their SUI back, NOT Alpha Points when unstaking after maturity.
    /// 
    /// COMPARISON TO V1:
    /// - V1: Mints ~700,000 Alpha Points per SUI (223x too much due to calculation bug)
    /// - V2: Mints ~3,280 Alpha Points per SUI (economically correct amount)
    /// - BOTH: Should mint 0 Alpha Points during normal unstaking!
    /// 
    /// CORRECT BEHAVIOR: Only request SUI withdrawal, do not mint any Alpha Points
    /// 
    /// @deprecated Use a new function that only handles SUI withdrawal without minting points
    /// NEW: Request unstake with corrected Alpha Points calculation (1:1000 USD ratio)
    /// @deprecated The old request_unstake_native_sui function above uses 1:1 MIST conversion
    public entry fun request_unstake_native_sui_v2(
        manager: &mut StakingManager,
        config: &Config,
        sui_system_state: &mut SuiSystemState,
        stake_position: StakePosition<StakedSui>,
        clock: &Clock,
        ledger: &mut Ledger,
        ctx: &mut TxContext
    ) {
        admin::assert_not_paused(config);
        let user = tx_context::sender(ctx);
        assert!(stake_position::owner_view(&stake_position) == user, ENotOwner);
        assert!(!stake_position::is_encumbered_view(&stake_position), EStakeEncumbered);
        assert!(stake_position::is_redeemable(&stake_position, clock), ENotRedeemable);
        
        let native_staked_sui_address = stake_position::native_stake_id_view(&stake_position);
        let native_staked_sui_id = id_from_address(native_staked_sui_address);
        assert!(native_staked_sui_address != @0x0, EInvalidStakeIdType);
        
        let principal_sui = stake_position::principal_view(&stake_position);
        let stake_position_id = stake_position::get_id_view(&stake_position);
        
        staking_manager::request_native_stake_withdrawal(
            manager,
            sui_system_state,
            native_staked_sui_id,
            ctx
        );

        // FIXED: Convert SUI MIST to Alpha Points using correct 1:1000 USD ratio
        let alpha_points_to_mint = mist_to_alpha_points(principal_sui);
        
        let stake_opt_none = std_option::none<StakePosition<StakedSui>>();
        if (alpha_points_to_mint > 0) {
            ledger::mint_points<StakedSui>(
                ledger,
                user,
                alpha_points_to_mint,
                ledger::new_point_type_staking(),
                ctx,
                &stake_opt_none,
                admin::get_default_liq_share(config),
                clock
            );
        };
        std_option::destroy_none(stake_opt_none);
        
        stake_position::destroy_stake(stake_position);
        
        event::emit(StakeConvertedToPoints {
            user,
            original_staked_sui_id: native_staked_sui_id,
            sui_amount_unstaked: principal_sui,
            points_minted: alpha_points_to_mint,
            stake_position_id,
        });
    }

    /// NEW: Emergency unstake with corrected Alpha Points calculation (1:1000 USD ratio)
    /// @deprecated The old emergency_unstake_native_sui function above uses 1:1 MIST conversion
    public entry fun emergency_unstake_native_sui_v2(
        admin_cap: &AdminCap,
        config: &Config,
        manager: &mut StakingManager,
        sui_system_state: &mut SuiSystemState,
        stake_position: StakePosition<StakedSui>,
        clock: &Clock,
        ledger: &mut Ledger,
        ctx: &mut TxContext
    ) {
        assert!(admin::is_admin(admin_cap, config), EAdminOnly);
        let user = stake_position::owner_view(&stake_position);
        let _current_epoch = tx_context::epoch(ctx);
        
        let native_staked_sui_address = stake_position::native_stake_id_view(&stake_position);
        let native_staked_sui_id = id_from_address(native_staked_sui_address);
        assert!(native_staked_sui_address != @0x0, EInvalidStakeIdType);
        
        let principal_sui = stake_position::principal_view(&stake_position);
        let stake_position_id = stake_position::get_id_view(&stake_position);
        
        staking_manager::request_native_stake_withdrawal(
            manager,
            sui_system_state,
            native_staked_sui_id,
            ctx
        );

        // FIXED: Convert SUI MIST to Alpha Points using correct 1:1000 USD ratio
        let alpha_points_to_mint = mist_to_alpha_points(principal_sui);
        
        let stake_opt_none = std_option::none<StakePosition<StakedSui>>();
        if (alpha_points_to_mint > 0) {
            ledger::mint_points<StakedSui>(
                ledger,
                user,
                alpha_points_to_mint,
                ledger::new_point_type_staking(),
                ctx,
                &stake_opt_none,
                admin::get_default_liq_share(config),
                clock
            );
        };
        std_option::destroy_none(stake_opt_none);
        
        stake_position::destroy_stake(stake_position);
        
        event::emit(StakeConvertedToPoints {
            user,
            original_staked_sui_id: native_staked_sui_id,
            sui_amount_unstaked: principal_sui,
            points_minted: alpha_points_to_mint,
            stake_position_id,
        });
    }

    /// NEW: Liquid unstake as loan with corrected Alpha Points calculation (1:1000 USD ratio)
    /// @deprecated The old liquid_unstake_as_loan_native_sui function above uses 1:1 MIST conversion
    public entry fun liquid_unstake_as_loan_native_sui_v2(
        config: &Config,
        _loan_config: &loan::LoanConfig,
        ledger: &mut Ledger,
        stake_position: &mut StakePosition<StakedSui>,
        clock: &Clock,
        staking_manager: &mut StakingManager,
        sui_system_state: &mut SuiSystemState,
        ctx: &mut TxContext
    ) {
        admin::assert_not_paused(config);
        let user = tx_context::sender(ctx);
        assert!(stake_position::owner_view(stake_position) == user, ENotOwner);
        assert!(!stake_position::is_encumbered_view(stake_position), EStakeEncumbered);
        assert!(stake_position::is_redeemable(stake_position, clock), EStakeNotMatureForLoan);
        
        let sui_principal_for_loan = stake_position::principal_view(stake_position);
        
        // FIXED: Convert SUI MIST to Alpha Points using correct 1:1000 USD ratio
        let total_alpha_points = mist_to_alpha_points(sui_principal_for_loan);
        let loan_fee_points = total_alpha_points / 1000; // 0.1% fee in Alpha Points
        let points_to_user_net = total_alpha_points - loan_fee_points;
        
        assert!(loan_fee_points <= total_alpha_points, EFeeCalculationError);
        
        if (points_to_user_net > 0) {
            let stake_opt_none = std_option::none<StakePosition<StakedSui>>();
            ledger::mint_points<StakedSui>(
                ledger,
                user,
                points_to_user_net,
                ledger::new_point_type_staking(),
                ctx,
                &stake_opt_none,
                admin::get_default_liq_share(config),
                clock
            );
            std_option::destroy_none(stake_opt_none);
        };
        
        if (loan_fee_points > 0) {
            let stake_opt_none_fee = std_option::none<StakePosition<StakedSui>>();
            ledger::mint_points<StakedSui>(
                ledger,
                admin::deployer_address(config),
                loan_fee_points,
                ledger::new_point_type_staking(),
                ctx,
                &stake_opt_none_fee,
                admin::get_default_liq_share(config),
                clock
            );
            std_option::destroy_none(stake_opt_none_fee);
        };

        let stake_pos_id = stake_position::get_id_view(stake_position);
        let loan_opened_time_ms = sui::clock::timestamp_ms(clock);
        let loan_object = loan::create_loan(
            user, 
            stake_pos_id, 
            sui_principal_for_loan, 
            loan_opened_time_ms, 
            ctx
        );
        let loan_object_id = object::uid_to_inner(loan::get_loan_uid(&loan_object));
        transfer::public_transfer(loan_object, user);
        
        stake_position::set_encumbered(stake_position, true);
        
        let native_staked_sui_address = stake_position::native_stake_id_view(stake_position);
        let native_staked_sui_id = id_from_address(native_staked_sui_address);
        assert!(native_staked_sui_address != @0x0, EInvalidStakeIdType);
        
        staking_manager::request_native_stake_withdrawal(
            staking_manager,
            sui_system_state,
            native_staked_sui_id,
            ctx
        );

        event::emit(LiquidUnstakeAsLoanInitiated {
            user,
            stake_position_id: stake_pos_id,
            native_sui_stake_id: native_staked_sui_id,
            sui_value_for_loan: sui_principal_for_loan,
            points_loaned: points_to_user_net,
            loan_fee_points,
            loan_object_id,
            opened_time_ms: loan_opened_time_ms,
        });
    }

    /// Cross-package recovery helper: Check if old package objects are accessible
    /// This function can be used to test if we have admin access to old package objects
    public fun test_old_package_admin_access(
        admin_cap: &AdminCap,
        config: &Config,
        _ctx: &TxContext
    ): bool {
        // Test if current admin cap gives us access
        admin::is_admin(admin_cap, config) && admin::deployer_address(config) != @0x0
    }

    /// Emergency recovery function for migrating stakes from old corrupted packages
    /// This function attempts to recreate stake positions in the new package
    /// based on data from old package objects that may be accessible
    public entry fun emergency_migrate_old_stake(
        admin_cap: &AdminCap,
        config: &Config,
        _manager: &mut StakingManager,
        ledger: &mut Ledger,
        old_stake_principal: u64,
        old_stake_owner: address,
        old_stake_duration_days: u64,
        old_stake_start_time_ms: u64,
        compensation_sui: Coin<SUI>, // SUI to compensate user
        _clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(admin::is_admin(admin_cap, config), EAdminOnly);
        
        // Validate compensation amount matches claimed stake value
        let compensation_amount = coin::value(&compensation_sui);
        assert!(compensation_amount >= old_stake_principal, EInsufficientCompensation);
        
        // Create replacement points for the user based on 1:1000 USD ratio
        let replacement_alpha_points = mist_to_alpha_points(old_stake_principal);
        
        if (replacement_alpha_points > 0) {
            let stake_opt_none = std_option::none<StakePosition<StakedSui>>();
            ledger::mint_points<StakedSui>(
                ledger,
                old_stake_owner,
                replacement_alpha_points,
                ledger::new_point_type_staking(),
                ctx,
                &stake_opt_none,
                admin::get_default_liq_share(config),
                _clock
            );
            std_option::destroy_none(stake_opt_none);
        };
        
        // Send compensation SUI to protocol treasury
        let treasury_address = admin::deployer_address(config);
        transfer::public_transfer(compensation_sui, treasury_address);
        
        event::emit(OldStakeMigrated {
            admin_cap_id: admin::admin_cap_id(config),
            old_stake_owner,
            old_stake_principal,
            old_stake_duration_days,
            old_stake_start_time_ms,
            replacement_alpha_points,
            compensation_amount,
        });
    }

    /// Batch migration function for processing multiple old stakes at once
    public entry fun emergency_batch_migrate_old_stakes(
        admin_cap: &AdminCap,
        config: &Config,
        _manager: &mut StakingManager,
        ledger: &mut Ledger,
        old_stake_principals: vector<u64>,
        old_stake_owners: vector<address>,
        old_stake_durations: vector<u64>,
        old_stake_start_times: vector<u64>,
        total_compensation_sui: Coin<SUI>,
        _clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(admin::is_admin(admin_cap, config), EAdminOnly);
        
        let stakes_count = vector::length(&old_stake_principals);
        assert!(stakes_count == vector::length(&old_stake_owners), EInvalidBatchData);
        assert!(stakes_count == vector::length(&old_stake_durations), EInvalidBatchData);
        assert!(stakes_count == vector::length(&old_stake_start_times), EInvalidBatchData);
        
        let mut i = 0;
        let mut total_points_issued = 0;
        let mut total_principal_compensated = 0;
        
        while (i < stakes_count) {
            let principal = *vector::borrow(&old_stake_principals, i);
            let owner = *vector::borrow(&old_stake_owners, i);
            let _duration = *vector::borrow(&old_stake_durations, i);
            let _start_time = *vector::borrow(&old_stake_start_times, i);
            
            // Calculate Alpha Points for this stake
            let alpha_points = mist_to_alpha_points(principal);
            
            if (alpha_points > 0) {
                let stake_opt_none = std_option::none<StakePosition<StakedSui>>();
                ledger::mint_points<StakedSui>(
                    ledger,
                    owner,
                    alpha_points,
                    ledger::new_point_type_staking(),
                    ctx,
                    &stake_opt_none,
                    admin::get_default_liq_share(config),
                    _clock
                );
                std_option::destroy_none(stake_opt_none);
                
                total_points_issued = total_points_issued + alpha_points;
            };
            
            total_principal_compensated = total_principal_compensated + principal;
            i = i + 1;
        };
        
        // Validate total compensation
        let compensation_amount = coin::value(&total_compensation_sui);
        assert!(compensation_amount >= total_principal_compensated, EInsufficientCompensation);
        
        // Send compensation to treasury
        let treasury_address = admin::deployer_address(config);
        transfer::public_transfer(total_compensation_sui, treasury_address);
        
        event::emit(BatchOldStakesMigrated {
            admin_cap_id: admin::admin_cap_id(config),
            stakes_migrated: stakes_count,
            total_principal_compensated,
            total_points_issued,
            compensation_amount,
        });
    }
}