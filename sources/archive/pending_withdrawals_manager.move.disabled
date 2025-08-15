/// Module for managing SUI withdrawal tickets that are in the cooldown period.
/// NOTE: With current understanding of native SUI unstaking, this module may not be used for that flow,
/// as the user receives the StakedSui (cooldown) object directly.
module alpha_points::pending_withdrawals_manager {
    use sui::table::{Self, Table, contains as table_contains, add as table_add, borrow as table_borrow};
    use sui::object::{new as object_new}; // UID and ID will be sui::object::UID / sui::object::ID

    /// Error if the withdrawal ticket is not found for the given ID.
    const EWithdrawalTicketNotFound: u64 = 1;

    /// Shared object holding the table of SUI withdrawal tickets.
    /// Stores original StakedSui ID and its expected amount.
    public struct PendingWithdrawalsManager has key {
        id: sui::object::UID, // Qualified
        /// Table mapping the original StakedSui object ID to its expected principal amount.
        withdrawal_info: Table<sui::object::ID, u64>, // Qualified
    }

    // Removed commented out PendingWithdrawalsManagerCap struct and its doc comment

    // --- Events ---

    public struct WithdrawalInfoStored has store, copy, drop {
        manager_id: sui::object::ID, // Qualified
        original_staked_sui_id: sui::object::ID, // Qualified
        expected_amount: u64,
    }

    // Commented out as its emitter function is commented out
    // public struct ProtocolWithdrawalCompletedAndEscrowed has store, copy, drop {
    //     manager_id: sui::object::ID,
    //     original_staked_sui_id: sui::object::ID,
    //     escrowed_sui_amount: u64,
    // }

    /// Initializes the PendingWithdrawalsManager and shares it.
    fun init(ctx: &mut sui::tx_context::TxContext) { // Qualified
        let manager = PendingWithdrawalsManager {
            id: object_new(ctx),
            withdrawal_info: table::new(ctx),
        };
        sui::transfer::share_object(manager); // Qualified
    }

    /// Stores information about a SUI withdrawal being processed.
    public(package) fun store_pending_withdrawal_info(
        manager: &mut PendingWithdrawalsManager,
        original_staked_sui_id: sui::object::ID, // Qualified
        expected_amount: u64,
        _ctx: &mut sui::tx_context::TxContext // Qualified
    ) {
        table_add(&mut manager.withdrawal_info, original_staked_sui_id, expected_amount);
        sui::event::emit(WithdrawalInfoStored {
            manager_id: sui::object::uid_to_inner(&manager.id), // Corrected to use manager.id
            original_staked_sui_id: original_staked_sui_id,
            expected_amount: expected_amount,
        });
    }

    /*
    /// Admin function to complete the withdrawal of SUI.
    /// This function now expects the actual StakedSui object (in cooldown state) to be passed in,
    /// as the manager no longer holds it.
    /// NOTE: This function needs redesign if the manager only holds IDs/amounts.
    /// For now, assuming it gets the StakedSui object from elsewhere to call sui_system::withdraw_stake.
    public entry fun admin_complete_and_escrow_withdrawal(
        _manager: &mut PendingWithdrawalsManager,
        admin_cap: &AdminCap,
        config: &Config,
        escrow_vault: &mut EscrowVault<SUI>,
        staked_sui_to_withdraw: StakedSui,
        sui_system_state_obj: &mut SuiSystemState,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(admin_is_admin(admin_cap, config), ENotAdmin);
        let original_staked_sui_id = sui::object::id(&staked_sui_to_withdraw);

        let sui_coin = sui_system::sui_system::withdraw_stake(
            sui_system_state_obj, 
            staked_sui_to_withdraw, 
            ctx
        );
        let escrowed_amount = coin_value(&sui_coin);
        escrow_deposit<SUI>(escrow_vault, sui_coin, ctx);
        sui::event::emit(ProtocolWithdrawalCompletedAndEscrowed {
            manager_id: sui::object::uid_to_inner(&_manager.id),
            original_staked_sui_id: original_staked_sui_id,
            escrowed_sui_amount: escrowed_amount,
        });
    }
    */

    // --- View Functions ---
    public fun has_pending_withdrawal_info(manager: &PendingWithdrawalsManager, original_staked_sui_id: sui::object::ID): bool {
        table_contains(&manager.withdrawal_info, original_staked_sui_id)
    }

    public fun get_pending_withdrawal_expected_amount(manager: &PendingWithdrawalsManager, original_staked_sui_id: sui::object::ID): u64 {
        assert!(has_pending_withdrawal_info(manager, original_staked_sui_id), EWithdrawalTicketNotFound);
        *table_borrow(&manager.withdrawal_info, original_staked_sui_id)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut sui::tx_context::TxContext) { // Qualified
        init(ctx);
    }
} 