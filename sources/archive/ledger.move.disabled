/// Module that manages the internal accounting of Alpha Points.
/// Tracks user balances and total supply using a shared Ledger object.
module alpha_points::ledger {
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::table::{Self as table_ops, Table as SuiTable};
    use alpha_points::stake_position::{Self as stake_position_ops, StakePosition};
    use sui::object::Self as object_ops;

    // Error constants
    const EInsufficientBalance: u64 = 1;
    const EInsufficientAvailableBalance: u64 = 2;
    const ERepaymentExceedsDebt: u64 = 6;
    const EOverflow: u64 = 7;
    const EInsufficientLockedBalance: u64 = 8;
    const EExceedsWeightCurve: u64 = 200;

    /// Enum to categorize different types of points being minted or tracked.
    public enum PointType has drop {
        Staking,
        GenericReward,
        LoanProceeds,
        FeeRevenue,
    }

    /// Public constructor for PointType::Staking variant.
    public fun new_point_type_staking(): PointType {
        PointType::Staking
    }

    /// Public constructor for PointType::GenericReward variant.
    public fun new_point_type_generic_reward(): PointType {
        PointType::GenericReward
    }

    /// Public constructor for PointType::LoanProceeds variant.
    public fun new_point_type_loan_proceeds(): PointType {
        PointType::LoanProceeds
    }

    /// Public constructor for PointType::FeeRevenue variant.
    public fun new_point_type_fee_revenue(): PointType {
        PointType::FeeRevenue
    }

    /// User's point balance details with available and locked amounts
    public struct PointBalance has key, store {
        id: UID,
        available: u64,
        locked: u64
    }

    /// Shared object holding the global ledger with point supply and user balances
    public struct Ledger has key {
        id: UID,
        balances: SuiTable<address, PointBalance>,
        bad_debt: SuiTable<address, u64>
    }

    // Events
    public struct Earned has copy, drop {
        user: address,
        amount: u64
    }

    public struct Spent has copy, drop {
        user: address,
        amount: u64
    }

    public struct Locked has copy, drop {
        user: address,
        amount: u64
    }

    public struct Unlocked has copy, drop {
        user: address,
        amount: u64
    }

    // === Core module functions ===

    /// Creates and shares the Ledger object
    fun init(ctx: &mut sui::tx_context::TxContext) {
        let ledger = Ledger {
            id: object_ops::new(ctx),
            balances: table_ops::new(ctx),
            bad_debt: table_ops::new(ctx)
        };
        transfer::share_object(ledger);
    }

    /// Increases user's available balance
    /// Creates entry if not exists
    public(package) fun internal_earn(
        ledger: &mut Ledger,
        user: address,
        amount: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        if (amount == 0) return;
        
        // Update user's entry in the Table (using 'balances' field)
        if (!table_ops::contains(&ledger.balances, user)) {
            table_ops::add(
                &mut ledger.balances,
                user,
                PointBalance { id: object_ops::new(ctx), available: amount, locked: 0 }
            );
        } else {
            let user_balance = table_ops::borrow_mut(&mut ledger.balances, user);
            let new_available = user_balance.available + amount;
            assert!(new_available >= user_balance.available, EOverflow);
            user_balance.available = new_available;
        };
        
        event::emit(Earned { user, amount });
    }

    /// Decreases user's available balance
    public(package) fun internal_spend(
        ledger: &mut Ledger,
        user: address,
        amount: u64,
        _ctx: &sui::tx_context::TxContext
    ) {
        if (amount == 0) return;
        assert!(table_ops::contains(&ledger.balances, user), EInsufficientBalance);
        let user_balance = table_ops::borrow_mut(&mut ledger.balances, user);
        assert!(user_balance.available >= amount, EInsufficientAvailableBalance);
        user_balance.available = user_balance.available - amount;

        event::emit(Spent { user, amount });
    }

    /// Moves amount from user's available to locked balance
    public(package) fun internal_lock(
        ledger: &mut Ledger,
        user: address,
        amount: u64,
        _ctx: &sui::tx_context::TxContext
    ) {
        if (amount == 0) return;
        assert!(table_ops::contains(&ledger.balances, user), EInsufficientBalance);
        let user_balance = table_ops::borrow_mut(&mut ledger.balances, user);
        assert!(user_balance.available >= amount, EInsufficientAvailableBalance);
        user_balance.available = user_balance.available - amount;
        let new_locked = user_balance.locked + amount;
        assert!(new_locked >= user_balance.locked, EOverflow);
        user_balance.locked = new_locked;
        event::emit(Locked { user, amount });
    }

    /// Moves amount from user's locked to available balance
    public(package) fun internal_unlock(
        ledger: &mut Ledger,
        user: address,
        amount: u64,
        _ctx: &sui::tx_context::TxContext
    ) {
        if (amount == 0) return;
        assert!(table_ops::contains(&ledger.balances, user), EInsufficientLockedBalance); // EInsufficientBalance might be more appropriate if we are not sure locked balance exists
        let user_balance = table_ops::borrow_mut(&mut ledger.balances, user);
        assert!(user_balance.locked >= amount, EInsufficientLockedBalance);
        user_balance.locked = user_balance.locked - amount;
        let new_available = user_balance.available + amount;
        assert!(new_available >= user_balance.available, EOverflow);
        user_balance.available = new_available;
        event::emit(Unlocked { user, amount });
    }

    /// Calculates points accrued since the last claim epoch.
    /// 
    /// ⚠️  KNOWN ISSUE: MATH IS INCORRECT - GIVING 223x TOO MANY POINTS
    /// Current logic gives flat rate per epoch instead of proper APY calculation
    /// 
    /// PROBLEM: 
    /// - points_rate_per_sui_per_epoch=100 means 100 points PER EPOCH per SUI
    /// - For 1 SUI staked 7 epochs = 700 points (should be ~3.14 points for 5% APY)
    /// - This is 223x more than intended APY-based rewards
    /// 
    /// CORRECT CALCULATION SHOULD BE:
    /// 1. principal_in_AP = (principal_mist * 3280) / 1e9  // Convert to Alpha Points value
    /// 2. points = (principal_in_AP * apy_bps * epochs) / (10000 * 365)  // APY-based
    /// 
    /// CANNOT FIX: Sui Move upgrade rules prevent changing public function logic
    /// TODO: Create new function with correct math in future upgrade
    /// 
    public fun calculate_accrued_points(
        principal: u64, // Principal in MIST
        points_rate_per_sui_per_epoch: u64, // Rate from Config
        last_claim_epoch: u64,
        current_epoch: u64
    ): u64 {
        if (current_epoch <= last_claim_epoch) {
            return 0 // No full epochs passed or invalid state
        };

        let elapsed_epochs = current_epoch - last_claim_epoch;

        // Calculation: (principal_sui * points_rate) * elapsed_epochs
        // principal is in MIST, rate is per SUI (10^9 MIST)
        // points = (principal / 10^9) * points_rate * elapsed_epochs
        // To avoid floating point, use: (principal * points_rate * elapsed_epochs) / 10^9

        // Using u128 for intermediate multiplication to prevent overflow
        let principal_u128 = (principal as u128);
        let rate_u128 = (points_rate_per_sui_per_epoch as u128);
        let elapsed_u128 = (elapsed_epochs as u128);

        let numerator = principal_u128 * rate_u128 * elapsed_u128;
        let denominator = 1_000_000_000u128; // 1 SUI in MIST

        let accrued_points = (numerator / denominator) as u64; // Integer division

        accrued_points
    }

    /// Public function to mint points for a user.
    /// Quota/cap logic should be enforced by the caller (e.g., PartnerCap or other integration points).
    public fun mint_points<T: store>(
        ledger: &mut Ledger,
        user: address,
        amount: u64,
        _point_type: PointType, // Retained for potential future categorization or logging
        ctx: &mut sui::tx_context::TxContext,
        stake_opt: &std::option::Option<StakePosition<T>>,
        liq_share: u64,
        clock: &Clock
    ) {
        enforce_weight_curve(stake_opt, amount, liq_share, clock);
        internal_earn(ledger, user, amount, ctx);
    }

    // --- Weight curve enforcement ---
    // Enforce amount <= weight(stake_secs, principal, liq_share) if stake is present
    public fun enforce_weight_curve<T: store>(stake_opt: &std::option::Option<StakePosition<T>>, amount: u64, liq_share: u64, clock_obj: &Clock) {
        if (std::option::is_some(stake_opt)) {
            let stake = std::option::borrow(stake_opt);
            let current_time_ms = clock::timestamp_ms(clock_obj);
            let weight = stake_position_ops::calculate_weight<T>(stake, current_time_ms, liq_share);
            assert!(amount <= weight, EExceedsWeightCurve);
        } // If stake_opt is none, the weight curve assertion is skipped for this call.
    }

    // === View functions ===

    public fun get_available_balance(ledger: &Ledger, user: address): u64 {
        if (!table_ops::contains(&ledger.balances, user)) {
            return 0
        };
        let balance = table_ops::borrow(&ledger.balances, user);
        let available = balance.available;
        available
    }

    public fun get_locked_balance(ledger: &Ledger, user: address): u64 {
        if (!table_ops::contains(&ledger.balances, user)) {
            return 0
        };
        let balance = table_ops::borrow(&ledger.balances, user);
        let locked = balance.locked;
        locked
    }

    public fun get_total_balance(ledger: &Ledger, user: address): u64 {
        if (!table_ops::contains(&ledger.balances, user)) {
            return 0
        };
        let balance = table_ops::borrow(&ledger.balances, user);
        let total_balance = balance.available + balance.locked;
        total_balance
    }

    /// Internal function to add to a user's bad debt amount
    /// This would be called during liquidation/forfeiture if recovered value is insufficient.
    public(package) fun internal_add_bad_debt(ledger: &mut Ledger, user: address, amount: u64) {
        if (amount == 0) { return };
        if (!table_ops::contains(&ledger.bad_debt, user)) {
            table_ops::add(&mut ledger.bad_debt, user, amount);
        } else {
            let current_debt_ref = table_ops::borrow_mut(&mut ledger.bad_debt, user);
            *current_debt_ref = *current_debt_ref + amount;
        }
    }

    /// Get the current bad debt amount for a user
    public fun get_bad_debt(ledger: &Ledger, user: address): u64 {
        if (table_ops::contains(&ledger.bad_debt, user)) {
            let current_debt_ref = table_ops::borrow(&ledger.bad_debt, user);
            let current_debt = *current_debt_ref;
            current_debt
        } else {
            0
        }
    }

    /// Check if a user has any outstanding bad debt
    public fun has_bad_debt(ledger: &Ledger, user: address): bool {
        get_bad_debt(ledger, user) > 0
    }

    /// Internal function to subtract from a user's bad debt amount.
    /// Removes the user entry if debt becomes 0.
    public(package) fun internal_remove_bad_debt(ledger: &mut Ledger, user: address, amount: u64) {
        if (amount == 0) { return };

        assert!(table_ops::contains(&ledger.bad_debt, user), ERepaymentExceedsDebt); 
        let current_debt_ref = table_ops::borrow_mut(&mut ledger.bad_debt, user);
        let current_debt = *current_debt_ref;

        assert!(current_debt >= amount, ERepaymentExceedsDebt);
        *current_debt_ref = current_debt - amount;

        if (*current_debt_ref == 0) {
            table_ops::remove(&mut ledger.bad_debt, user);
        }
    }

    // === Test-only functions ===

    #[test_only]
    /// Initialize the Ledger for testing. Calls the internal init function.
    public(package) fun init_for_testing(ctx: &mut sui::tx_context::TxContext) {
        init(ctx);
    }

    #[test_only]
    /// Helper function for tests to call internal_earn.
    public(package) fun test_earn(
        ledger: &mut Ledger,
        _gov_cap: &GovernCap, // Assuming GovernCap is defined elsewhere or a placeholder
        user: address,
        amount: u64,
        ctx: &mut sui::tx_context::TxContext,
        stake_opt: &std::option::Option<StakePosition<u8>>, // u8 as a generic type for testing
        liq_share: u64,
        clock: &Clock
    ) {
        // The _current_epoch_val parameter in mint_points is not strictly needed now
        // but kept for consistency if other callers might pass it. Here, passing 0 or a dummy epoch.
        mint_points(ledger, user, amount, new_point_type_staking(), ctx, stake_opt, liq_share, clock);
    }

    #[test_only]
    /// Helper function for tests to call internal_spend.
    public(package) fun test_spend(
        ledger: &mut Ledger,
        _gov_cap: &GovernCap, // Requires GovernCap import or be a placeholder
        user: address,
        amount: u64,
        ctx: &sui::tx_context::TxContext
    ) {
        internal_spend(ledger, user, amount, ctx);
    }

    #[test_only]
    /// Helper function for tests to call internal_lock.
    public(package) fun test_lock(
        ledger: &mut Ledger,
        _gov_cap: &GovernCap, // Requires GovernCap import or be a placeholder
        user: address,
        amount: u64,
        ctx: &sui::tx_context::TxContext
    ) {
        internal_lock(ledger, user, amount, ctx);
    }

    #[test_only]
    /// Helper function for tests to call internal_unlock.
    public(package) fun test_unlock(
        ledger: &mut Ledger,
        _gov_cap: &GovernCap, // Requires GovernCap import or be a placeholder
        user: address,
        amount: u64,
        ctx: &sui::tx_context::TxContext
    ) {
        internal_unlock(ledger, user, amount, ctx);
    }

} // End of module alpha_points::ledger