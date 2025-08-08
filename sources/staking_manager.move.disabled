/// Module responsible for managing the protocol's collection of native StakedSui objects.
module alpha_points::staking_manager {
    // use sui::object; // Removed as it's a duplicate alias provided by default
    // use sui::tx_context; // Removed as it's a duplicate alias provided by default
    use sui::table::{Self, Table};
    // use sui::transfer; // Removed, provided by default
    use sui_system::sui_system::{
        SuiSystemState,
        request_withdraw_stake as system_request_withdraw_stake
    };
    use sui_system::staking_pool::{StakedSui, staked_sui_amount};
    use sui::event;
    // use sui::balance::Balance; // Not used directly
    // use sui::sui::SUI; // Not used directly

    // Error Constants
    const EStakeNotFound: u64 = 0;
    // const ENotOwner: u64 = 1; // Unused const

    /// Shared object holding the table of native stakes managed by the protocol.
    public struct StakingManager has key {
        id: object::UID,
        /// Table mapping the StakedSui object ID to the StakedSui object itself.
        native_stakes: Table<object::ID, StakedSui>,
    }

    // Events
    public struct NativeStakeStored has store, copy, drop {
        manager_id: object::ID,
        stake_id: object::ID,
        amount: u64,
    }

    public struct NativeStakeWithdrawalRequested has store, copy, drop {
        manager_id: object::ID,
        stake_id: object::ID,
        amount: u64,
    }

    #[allow(unused_field)]
    public struct NativeStakeWithdrawn has store, copy, drop {
        manager_id: object::ID,
        original_stake_id: object::ID,
        amount_withdrawn: u64,
    }

    /// Creates and shares the StakingManager object during protocol initialization.
    fun init(ctx: &mut tx_context::TxContext) {
        let manager = StakingManager {
            id: object::new(ctx),
            native_stakes: table::new(ctx),
        };
        transfer::share_object(manager);
    }

    /// Adds a natively staked StakedSui object to the manager's tracking table.
    /// This function is intended to be called from integration.move after a successful native stake.
    public(package) fun store_native_stake(
        manager: &mut StakingManager,
        staked_sui: StakedSui,
        _ctx: &mut tx_context::TxContext
    ) {
        let stake_id = object::id(&staked_sui);
        let amount = staked_sui_amount(&staked_sui);
        table::add(&mut manager.native_stakes, stake_id, staked_sui);
        event::emit(NativeStakeStored {
            manager_id: object::id(manager),
            stake_id: stake_id,
            amount: amount
        });
    }

    /// Removes a StakedSui object from the manager and prepares it for withdrawal.
    /// This would be called before unstaking from the Sui system staking pool.
    public(package) fun request_native_stake_withdrawal(
        manager: &mut StakingManager,
        sui_system_state_obj: &mut SuiSystemState,
        staked_sui_id: object::ID,
        ctx: &mut tx_context::TxContext
    ) {
        let original_staked_sui = table::remove(&mut manager.native_stakes, staked_sui_id);
        let amount = staked_sui_amount(&original_staked_sui);

        system_request_withdraw_stake(
            sui_system_state_obj,
            original_staked_sui,
            ctx
        );

        event::emit(NativeStakeWithdrawalRequested {
            manager_id: object::id(manager),
            stake_id: staked_sui_id,
            amount: amount
        });
    }

    // === Test-only functions ===

    #[test_only]
    /// Initialize for testing.
    public fun init_for_testing(ctx: &mut tx_context::TxContext) {
        init(ctx);
    }

    // === View functions ===

    /// View function to get a reference to a StakedSui object by its ID.
    /// Useful for checks or read-only operations.
    public fun get_stake_by_id(manager: &StakingManager, stake_id: object::ID): &StakedSui {
        assert!(table::contains(&manager.native_stakes, stake_id), EStakeNotFound);
        table::borrow(&manager.native_stakes, stake_id)
    }

    public fun get_total_managed_stake(_manager: &StakingManager, _user: address): u64 {
        0
    }

    public fun get_stake_owner(_manager: &StakingManager, _stake_id: object::ID): address {
        @0x0
    }

    // View function to check if a native stake exists by ID
    public fun has_native_stake(manager: &StakingManager, stake_id: object::ID): bool {
        table::contains(&manager.native_stakes, stake_id)
    }

    /// Retrieves a reference to a StakedSui object by its ID from the native_stakes table.
    /// Panics if the stake_id does not exist in the table.
    public fun get_native_stake_balance(manager: &StakingManager, stake_id: object::ID): u64 {
        let native_stake = table::borrow(&manager.native_stakes, stake_id);
        staked_sui_amount(native_stake)
    }

    /// Returns the total count of stakes managed by this StakingManager
    public fun get_total_stakes_count(manager: &StakingManager): u64 {
        table::length(&manager.native_stakes)
    }
}
