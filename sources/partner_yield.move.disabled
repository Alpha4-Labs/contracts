/// Module for managing yield programs and partner collateral.
module alpha_points::partner_yield {
    // Import only what's needed, removing unused imports
    use sui::clock;
    use alpha_points::partner_flex::PartnerCapFlex;

    // === Error Constants ===
    const E_INVALID_YIELD_PROGRAM: u64 = 1;
    const E_INSUFFICIENT_COLLATERAL: u64 = 2;
    const E_YIELD_PROGRAM_PAUSED: u64 = 3;
    const E_MAX_EXPOSURE_REACHED: u64 = 5;
    const E_NOT_YIELD_PARTNER: u64 = 7;

    // === Structs ===

    /// Represents a yield program that partners can opt into
    public struct YieldProgram has key, store {
        id: object::UID,
        name: std::string::String,
        description: std::string::String,
        yield_generator_address: address,
        apy_percentage: u64,
        min_stake_amount: u64,
        max_stake_amount: u64,
        is_active: bool,
        audit_report_url: std::string::String,
        last_audit_timestamp_ms: u64,
        total_staked: u64,
        total_rewards_paid: u64
    }

    /// Tracks a partner's yield position
    public struct YieldPosition has key, store {
        id: object::UID,
        owner: address, // Keep as address for now
        yield_program_id: object::ID,
        staked_amount: u64,
        start_time_ms: u64,
        last_claim_timestamp_ms: u64,
        total_claimed_rewards: u64,
        is_active: bool
    }

    /// Admin capability for managing yield programs
    public struct YieldAdminCap has key {
        id: object::UID,
        admin: address
    }

    // === Events ===

    public struct YieldProgramCreated has copy, drop {
        program_id: object::ID,
        name: std::string::String,
        yield_generator_address: address
    }

    public struct YieldPositionCreated has copy, drop {
        position_id: object::ID,
        owner: address,
        staked_amount: u64
    }

    public struct YieldRewardClaimed has copy, drop {
        position_id: object::ID,
        owner: address,
        amount: u64,
        timestamp_ms: u64
    }

    public struct YieldProgramDeactivated has copy, drop {
        program_id: object::ID,
        reason: std::string::String
    }

    // === Functions ===

    /// Creates a new yield program
    public entry fun create_yield_program(
        admin_cap: &YieldAdminCap,
        name: std::string::String,
        description: std::string::String,
        yield_generator_address: address,
        apy_percentage: u64,
        min_stake_amount: u64,
        max_stake_amount: u64,
        audit_report_url: std::string::String,
        clock_obj: &clock::Clock, // Fixed parameter name
        ctx: &mut tx_context::TxContext
    ): (object::ID, YieldProgramCreated) {
        // Validate admin
        assert!(tx_context::sender(ctx) == admin_cap.admin, E_INVALID_YIELD_PROGRAM);
        
        // Create program
        let program = YieldProgram {
            id: object::new(ctx),
            name,
            description,
            yield_generator_address,
            apy_percentage,
            min_stake_amount,
            max_stake_amount,
            is_active: true,
            audit_report_url,
            last_audit_timestamp_ms: clock::timestamp_ms(clock_obj),
            total_staked: 0,
            total_rewards_paid: 0
        };
        
        let program_id = object::id(&program);
        transfer::share_object(program);
        
        (program_id, YieldProgramCreated {
            program_id,
            name: std::string::utf8(b"Yield Program"),
            yield_generator_address
        })
    }

    /// Opens a yield position for a partner
    public entry fun stake_in_yield_program(
        _partner_cap: &mut PartnerCapFlex, // Made unused since we can't access fields
        program: &mut YieldProgram,
        stake_amount: u64,
        clock_obj: &clock::Clock,
        ctx: &mut tx_context::TxContext
    ): (object::ID, YieldPositionCreated) {
        let partner_address = tx_context::sender(ctx);
        
        // Validate stake amount
        assert!(stake_amount >= program.min_stake_amount, E_INSUFFICIENT_COLLATERAL);
        assert!(stake_amount <= program.max_stake_amount, E_MAX_EXPOSURE_REACHED);
        
        // Create position
        let position = YieldPosition {
            id: object::new(ctx),
            owner: partner_address, // Keep as address
            yield_program_id: object::id(program),
            staked_amount: stake_amount,
            start_time_ms: clock::timestamp_ms(clock_obj),
            last_claim_timestamp_ms: clock::timestamp_ms(clock_obj),
            total_claimed_rewards: 0,
            is_active: true
        };
        
        let position_id = object::id(&position);
        transfer::share_object(position);
        
        // Update program stats
        program.total_staked = program.total_staked + stake_amount;
        
        // Note: Cannot directly access private fields of PartnerCapFlex
        
        (position_id, YieldPositionCreated {
            position_id,
            owner: partner_address,
            staked_amount: stake_amount
        })
    }

    /// Claims accumulated yield from a position
    public entry fun claim_yield_rewards(
        _partner_cap: &mut PartnerCapFlex,
        position: &mut YieldPosition,
        program: &mut YieldProgram,
        clock_obj: &clock::Clock,
        ctx: &mut tx_context::TxContext
    ): YieldRewardClaimed {
        let partner_address = tx_context::sender(ctx);
        assert!(position.owner == partner_address, E_NOT_YIELD_PARTNER);
        assert!(position.is_active, E_YIELD_PROGRAM_PAUSED);
        
        let current_time = clock::timestamp_ms(clock_obj);
        let time_elapsed_ms = current_time - position.last_claim_timestamp_ms;
        let reward_amount = calculate_rewards(position.staked_amount, program.apy_percentage, time_elapsed_ms);
        
        // Update position
        position.last_claim_timestamp_ms = current_time;
        position.total_claimed_rewards = position.total_claimed_rewards + reward_amount;
        
        // Update program stats
        program.total_rewards_paid = program.total_rewards_paid + reward_amount;
        
        YieldRewardClaimed {
            position_id: object::id(position),
            owner: partner_address,
            amount: reward_amount,
            timestamp_ms: current_time
        }
    }

    /// Closes a yield position and returns collateral
    public entry fun unstake_from_yield_program(
        _partner_cap: &mut PartnerCapFlex,
        position: &mut YieldPosition,
        program: &mut YieldProgram,
        clock_obj: &clock::Clock,
        ctx: &mut tx_context::TxContext
    ): (u64, YieldPositionCreated) {
        let partner_address = tx_context::sender(ctx);
        assert!(position.owner == partner_address, E_NOT_YIELD_PARTNER);
        assert!(position.is_active, E_YIELD_PROGRAM_PAUSED);
        
        // Calculate final rewards
        let current_time = clock::timestamp_ms(clock_obj);
        let time_elapsed_ms = current_time - position.last_claim_timestamp_ms;
        let final_reward = calculate_rewards(position.staked_amount, program.apy_percentage, time_elapsed_ms);
        
        // Update program stats
        program.total_staked = program.total_staked - position.staked_amount;
        program.total_rewards_paid = program.total_rewards_paid + final_reward;
        
        // Deactivate position
        position.is_active = false;
        
        (position.staked_amount, YieldPositionCreated {
            position_id: object::id(position),
            owner: partner_address,
            staked_amount: position.staked_amount
        })
    }

    /// Emergency withdrawal function for blacklisted or paused programs
    public entry fun deactivate_yield_program(
        admin_cap: &YieldAdminCap,
        program: &mut YieldProgram,
        reason: std::string::String,
        ctx: &mut tx_context::TxContext
    ): YieldProgramDeactivated {
        let partner_address = tx_context::sender(ctx);
        assert!(admin_cap.admin == partner_address, E_NOT_YIELD_PARTNER);
        
        program.is_active = false;
        
        YieldProgramDeactivated {
            program_id: object::id(program),
            reason
        }
    }

    /// Updates a yield program's status
    public entry fun update_yield_program_audit(
        admin_cap: &YieldAdminCap,
        program: &mut YieldProgram,
        new_audit_report_url: option::Option<std::string::String>,
        clock_obj: &clock::Clock,
        ctx: &mut tx_context::TxContext
    ) {
        let _partner_address = tx_context::sender(ctx);
        assert!(admin_cap.admin == _partner_address, E_NOT_YIELD_PARTNER);
        
        if (option::is_some(&new_audit_report_url)) {
            program.audit_report_url = *option::borrow(&new_audit_report_url);
            program.last_audit_timestamp_ms = clock::timestamp_ms(clock_obj);
        };
    }

    // === View Functions ===

    public fun get_yield_program_details(program: &YieldProgram): (std::string::String, std::string::String, address, u64, u64, u64, bool, bool) {
        (
            program.name,
            program.description,
            program.yield_generator_address,
            program.apy_percentage,
            program.min_stake_amount,
            program.max_stake_amount,
            program.is_active,
            program.total_staked > 0
        )
    }

    public fun get_position_details(position: &YieldPosition): (address, object::ID, u64, u64, u64) {
        (
            position.owner,
            position.yield_program_id,
            position.staked_amount,
            position.total_claimed_rewards,
            position.last_claim_timestamp_ms
        )
    }

    // Helper functions
    fun calculate_rewards(staked_amount: u64, apy_percentage: u64, time_elapsed_ms: u64): u64 {
        // Convert APY to per-millisecond rate
        let ms_in_year = 31536000000; // 365 days in milliseconds
        let rate_per_ms = (apy_percentage as u128) * (staked_amount as u128) / (100 * ms_in_year);
        ((rate_per_ms * (time_elapsed_ms as u128)) / 100) as u64
    }
} 