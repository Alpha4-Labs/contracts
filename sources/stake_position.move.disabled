/// Module that defines and manages the user's stake representation as a Move object.
module alpha_points::stake_position {
    // use sui::object; // Removed as it's a duplicate alias provided by default
    // use sui::tx_context; // Removed as it's a duplicate alias provided by default
    use sui::event;
    use sui::clock::Clock;
    use std::u64; // Added for u64::sqrt

    // const ENotMature: u64 = 1;
    const EAlreadyClaimed: u64 = 2;
    const EInvalidDuration: u64 = 3;
    // const ENotOwner: u64 = 4; // Marked as unused

    const MS_PER_DAY: u64 = 86_400_000; // Milliseconds in a day

    /// Owned object representing a user's stake of asset T.
    /// T is phantom as the actual asset is in escrow.
    public struct StakePosition<phantom T: store> has key, store {
        id: object::UID,
        owner: address,
        // Generic field for the primary staked asset's ID if it's an object (e.g., StakedSui ID)
        // For non-object stakes (like raw SUI before it becomes StakedSui), this might be self ID or a placeholder.
        staked_sui_id: address, // Potentially rename to primary_stake_object_id or similar
        token_id: address, // Represents the type of token, can be address of the TypeName object
        amount: u64, // The amount of the staked asset T
        start_time_ms: u64, // Timestamp when the stake was created
        unlock_time_ms: u64, // Timestamp when the stake can be withdrawn
        last_claim_epoch: u64, // Last epoch points were claimed for this stake
        claimed_rewards: u64, // Total rewards claimed from this position
        encumbered: bool, // If the stake is used as collateral
    }

    // Event for stake creation
    public struct StakeCreated<phantom T: store> has store, copy, drop {
        stake_id: object::ID,
        owner: address,
        amount: u64,
        duration_days: u64,
        unlock_time_ms: u64,
        asset_type: std::ascii::String, // Store asset type T as string
    }

    // Event for when a stake is encumbered (used as collateral)
    public struct StakeEncumbered has store, copy, drop {
        stake_id: object::ID,
        owner: address,
    }

    // Event for when a stake is unencumbered
    public struct StakeUnencumbered has store, copy, drop {
        stake_id: object::ID,
        owner: address,
    }

    // === Test-only functions ===
    #[test_only]
    /// Helper function for tests to set encumbered flag
    public fun test_set_encumbered<T: store>(
        stake: &mut StakePosition<T>,
        value: bool
    ) {
        set_encumbered(stake, value);
    }

    // === Core module functions ===

    /// Creates a new StakePosition object using timestamps
    public(package) fun create_stake<T: store>(
        stake_amount: u64,
        duration_days: u64,
        _clock: &Clock, // Parameter clock unused, prefixed with underscore
        ctx: &mut tx_context::TxContext
    ): StakePosition<T> {
        assert!(duration_days > 0, EInvalidDuration);
        
        let start_time_ms = sui::clock::timestamp_ms(_clock); // Corrected call
        let current_epoch = ctx.epoch();
        let duration_ms = duration_days * MS_PER_DAY; 
        let unlock_time_ms = start_time_ms + duration_ms;

        let id = object::new(ctx);
        let owner = tx_context::sender(ctx);
        // Derive address from id BEFORE it's moved for placeholder usage
        let id_address_for_placeholders = object::uid_to_address(&id);

        event::emit(StakeCreated<T> {
            stake_id: object::uid_to_inner(&id),
            owner: owner,
            amount: stake_amount,
            duration_days: duration_days,
            unlock_time_ms: unlock_time_ms,
            asset_type: std::type_name::into_string(std::type_name::get<T>()) // Corrected assignment
        });

        StakePosition {
            id: id,
            owner: owner,
            staked_sui_id: id_address_for_placeholders, // Placeholder, to be updated if native SUI stake
            token_id: id_address_for_placeholders, // Placeholder, represents type T
            amount: stake_amount,
            start_time_ms: start_time_ms,
            unlock_time_ms: unlock_time_ms,
            last_claim_epoch: current_epoch,
            claimed_rewards: 0,
            encumbered: false,
        }
    }

    /// Consumes and destroys the stake object
    public(package) fun destroy_stake<T: store>(
        stake: StakePosition<T>
    ) {
        let StakePosition {
            id,
            owner: _,
            staked_sui_id: _,
            token_id: _,
            amount: _,
            start_time_ms: _,
            unlock_time_ms: _,
            last_claim_epoch: _,
            claimed_rewards: _,
            encumbered: _,
        } = stake;

        object::delete(id);
    }

    /// Sets the encumbered flag
    public(package) fun set_encumbered<T: store>(
        stake: &mut StakePosition<T>,
        value: bool
    ) {
        stake.encumbered = value;

        if (value) {
            event::emit(StakeEncumbered {
                stake_id: object::uid_to_inner(&stake.id),
                owner: stake.owner,
            });
        } else {
            event::emit(StakeUnencumbered {
                stake_id: object::uid_to_inner(&stake.id),
                owner: stake.owner,
            });
        }
    }

    /// Updates the last_claim_epoch field.
    /// Called internally after points are claimed.
    public(package) fun set_last_claim_epoch_mut<T: store>(
        stake: &mut StakePosition<T>,
        epoch: u64
    ) {
        assert!(epoch >= stake.last_claim_epoch, EAlreadyClaimed); // Ensure epoch is not in the past
        stake.last_claim_epoch = epoch;
    }

    // === View functions ===

    /// Returns the owner of the stake
    public fun owner_view<T: store>(stake: &StakePosition<T>): address {
        stake.owner
    }

    /// Returns the principal amount of the stake
    public fun principal_view<T: store>(stake: &StakePosition<T>): u64 {
        stake.amount
    }

    /// Returns the duration in days
    public fun duration_days_view<T: store>(stake: &StakePosition<T>): u64 {
        (stake.unlock_time_ms - stake.start_time_ms) / MS_PER_DAY
    }

    /// Returns the unlock timestamp in milliseconds
    public fun unlock_time_ms_view<T: store>(stake: &StakePosition<T>): u64 {
        stake.unlock_time_ms
    }
    
    /// Returns the start timestamp in milliseconds
    public fun start_time_ms_view<T: store>(stake: &StakePosition<T>): u64 {
        stake.start_time_ms
    }

    /// Returns whether the stake is encumbered
    public fun is_encumbered_view<T: store>(stake: &StakePosition<T>): bool {
        stake.encumbered
    }

    /// Returns the Option<ID> of the associated native stake, if any
    public fun native_stake_id_view<T: store>(stake: &StakePosition<T>): address {
        stake.staked_sui_id
    }

    /// Returns the epoch when points were last claimed for this stake
    public fun last_claim_epoch_view<T: store>(stake: &StakePosition<T>): u64 {
        stake.last_claim_epoch
    }

    /// Returns whether the stake is mature based on the current epoch
    public fun is_mature<T: store>(stake: &StakePosition<T>, _clock: &Clock): bool {
        sui::clock::timestamp_ms(_clock) >= stake.unlock_time_ms // Corrected call, clock unused prefixed
    }

    /// Returns whether the stake is redeemable (mature and not encumbered)
    public fun is_redeemable<T: store>(stake: &StakePosition<T>, _clock: &Clock): bool {
        (sui::clock::timestamp_ms(_clock) >= stake.unlock_time_ms) && !is_encumbered_view(stake) // Corrected call, clock unused prefixed
    }

    /// Returns the object ID
    public fun get_id_view<T: store>(stake: &StakePosition<T>): object::ID {
        object::uid_to_inner(&stake.id)
    }

    /// Borrows an immutable reference from a mutable one
    public fun borrow_as_immutable<T: store>(stake: &mut StakePosition<T>): &StakePosition<T> {
        stake
    }

    // === Mutators ===

    public(package) fun add_claimed_rewards_mut<T: store>(
        stake: &mut StakePosition<T>,
        rewards: u64
    ) {
        stake.claimed_rewards = stake.claimed_rewards + rewards;
    }

    public(package) fun set_native_stake_id_mut<T: store>(
        stake: &mut StakePosition<T>,
        native_id: object::ID
    ) {
        stake.staked_sui_id = object::id_to_address(&native_id);
    }

    // Public getter for MS_PER_DAY
    public fun get_ms_per_day(): u64 {
        MS_PER_DAY
    }

    public fun calculate_weight<T: store>(
        stake: &StakePosition<T>,
        current_timestamp_ms: u64,
        liq_share: u64
    ): u64 {
        let principal = stake.amount;
        let stake_ms = if (current_timestamp_ms >= stake.start_time_ms) {
            current_timestamp_ms - stake.start_time_ms
        } else {
            0
        };
        let stake_secs = stake_ms / 1000; // Convert ms to seconds

        let p = u64::sqrt(principal);
        let t = u64::sqrt(stake_secs);

        let denominator = 1 + liq_share;
        // Denominator will always be > 0 since liq_share is u64.
        // If liq_share could be such that 1 + liq_share is 0 (e.g. if it were signed or specific value like u64::MAX making it wrap),
        // then an assertion `assert!(denominator > 0, ESomeError);` would be good.
        // For u64, 1 + liq_share is always >= 1.
        (p * t) / denominator
    }
}