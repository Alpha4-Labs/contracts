/// Module that manages protocol configuration, capabilities, and global pause state.
module alpha_points::admin {
    // use sui::object; // Removed duplicate alias
    // use sui::transfer; // Removed duplicate alias
    // use sui::tx_context; // Removed duplicate alias
    use sui::event;
    // use sui::clock::{Self, Clock}; // Clock might become unused
    
    // Removed unused internal module imports
    // use alpha_points::ledger;
    // use alpha_points::escrow;
    // use alpha_points::oracle;
    // use alpha_points::loan;
    // use alpha_points::staking_manager;
    
    // Error constants
    // const EProtocolPaused: u64 = 1; // May become unused
    // const EUnauthorized: u64 = 2; // May become unused
    const EInvalidCaller: u64 = 0;
    const EPaused: u64 = 2;
    // Removed: const ENotPaused: u64 = 3;
    const EZeroPointsRate: u64 = 1;
    const EAdminOnly: u64 = 3;
    
    /// Singleton capability for protocol owner actions
    public struct GovernCap has key, store {
        id: object::UID,
        auth_key: address
    }
    
    /// Capability to update oracles
    public struct OracleCap has key, store {
        id: object::UID,
        auth_key: address
    }
    
    /// Capability that grants administrative rights.
    /// Held by the deployer.
    public struct AdminCap has key, store {
        id: object::UID
    }
    
    /// Capability that allows bypassing partner cap rules for testing
    public struct TestnetBypassCap has key, store {
        id: object::UID
    }
    
    /// Configuration object holding protocol parameters.
    /// ⚠️  ISSUE: Currently interpreted as points PER EPOCH per SUI (should be APY bps)
    /// Current value 100 = 100 points per epoch per SUI (223x too much!)
    /// Should be APY basis points (500 = 5% APY)
    /// CANNOT CHANGE: Upgrade rules prevent changing struct field interpretation
    public struct Config has key {
        id: object::UID,
        deployer: address, // Address of the deployer/protocol
        paused: bool, // Protocol pause state
        points_rate: u64, // ⚠️  ISSUE: Currently interpreted as points PER EPOCH per SUI (should be APY bps)
                         // Current value 100 = 100 points per epoch per SUI (223x too much!)
                         // Should be APY basis points (500 = 5% APY)
                         // CANNOT CHANGE: Upgrade rules prevent changing struct field interpretation
        target_validator: address, // Target validator address for native SUI staking
        admin_cap_id: object::ID, // ID of the AdminCap, stored for convenience/events
        default_liq_share_for_weight_curve: u64, // Default liq_share for weight curve calculation
        forfeiture_grace_period_ms: u64,
        testnet_bypass_enabled: bool // New field to control testnet bypass
    }
    
    // Events
    public struct GovernCapTransferred has copy, drop {
        from: address,
        to: address
    }
    
    public struct OracleCapTransferred has copy, drop {
        from: address,
        to: address
    }
    
    public struct ProtocolPaused has copy, drop {
        dummy_field: bool,
    }
    
    public struct ProtocolUnpaused has copy, drop {
        dummy_field: bool,
    }
    
    public struct PointsRateUpdated has copy, drop {
        new_rate: u64
    }
    
    public struct ForfeitureGracePeriodUpdated has copy, drop {
        new_period_ms: u64
    }

    public struct TargetValidatorChanged has copy, drop {
        old_validator: address,
        new_validator: address
    }
    
    // === Test-only functions ===
    #[test_only]
    /// Initialize the admin module for testing
    public fun init_for_testing(ctx: &mut tx_context::TxContext) {
        let sender = tx_context::sender(ctx);
        let admin_cap = AdminCap { id: object::new(ctx) };
        let admin_cap_id = object::id(&admin_cap); // Store the ID

        transfer::transfer(
            Config {
                id: object::new(ctx),
                deployer: sender,
                paused: false,
                points_rate: 100, // Example: 100 points per SUI per epoch
                target_validator: @0x0, // Placeholder, set via update_target_validator
                admin_cap_id: admin_cap_id, // Store the AdminCap ID
                default_liq_share_for_weight_curve: 0, // Initialize with 0 (no dampening)
                forfeiture_grace_period_ms: 14 * 24 * 60 * 60 * 1000,
                testnet_bypass_enabled: true // Enable by default for testnet
            },
            sender
        );
        transfer::transfer(admin_cap, sender);
        transfer::transfer(GovernCap { id: object::new(ctx) }, sender);
    }
    
    // === Core module functions ===
    
    /// Creates GovernCap, OracleCap, Config, and initializes other modules.
    /// Transfers caps to deployer, shares Config and other shared objects.
    fun init(ctx: &mut tx_context::TxContext) {
        let sender = tx_context::sender(ctx);
        
        // Create and transfer governance capability
        let govern_cap = GovernCap {
            id: object::new(ctx),
            auth_key: sender 
        };
        transfer::transfer(govern_cap, sender);
        
        let oracle_cap = OracleCap {
            id: object::new(ctx),
            auth_key: sender 
        };
        transfer::transfer(oracle_cap, sender);
        
        let admin_cap = AdminCap { id: object::new(ctx) };
        let admin_cap_id_val = object::id(&admin_cap); // Renamed from admin_cap_actual_id for clarity
        transfer::public_transfer(admin_cap, sender); 
        
        let config = Config {
            id: object::new(ctx),
            admin_cap_id: admin_cap_id_val, // Use the renamed variable
            deployer: sender, // Corrected field name
            paused: false, // Corrected field name
            points_rate: 100,  // Corrected field name
            forfeiture_grace_period_ms: 14 * 24 * 60 * 60 * 1000,
            target_validator: @0x0, // Corrected field name
            default_liq_share_for_weight_curve: 0, // Initialize to 0
            testnet_bypass_enabled: true // Enable by default for testnet
        }; 
        
        // Create testnet bypass cap
        let testnet_bypass = TestnetBypassCap { id: object::new(ctx) };

        // Transfer capabilities
        transfer::public_transfer(testnet_bypass, sender);
        transfer::share_object(config); 
    }
    
    /// Updates config.paused. Emits PauseStateChanged.
    /// Requires GovernCap for authorization.
    public entry fun set_pause_state(
        config: &mut Config, 
        admin_cap: &AdminCap, 
        new_pause_state: bool, 
        _ctx: &tx_context::TxContext
    ) {
        assert!(object::id(admin_cap) == config.admin_cap_id, EInvalidCaller);
        config.paused = new_pause_state; // Corrected field name
        
        // Emit event
        if (config.paused) { // Corrected field name
            event::emit(ProtocolPaused { dummy_field: false });
        } else {
            event::emit(ProtocolUnpaused { dummy_field: false });
        }
    }
    
    /// Updates the points earning rate. Emits PointsRateChanged.
    /// Requires GovernCap for authorization.
    public entry fun set_points_rate(
        config: &mut Config,
        admin_cap: &AdminCap,
        new_rate: u64, // New points per SUI per epoch
        _ctx: &tx_context::TxContext // Context might be needed later
    ) {
        assert!(object::id(admin_cap) == config.admin_cap_id, EInvalidCaller);
        assert!(new_rate > 0, EZeroPointsRate);
        config.points_rate = new_rate; // Corrected field name
        event::emit(PointsRateUpdated { new_rate });
    }
    
    /// Get the forfeiture grace period from config
    public fun get_forfeiture_grace_period_ms(config: &Config): u64 {
        config.forfeiture_grace_period_ms
    }

    /// Updates the forfeiture grace period. Emits ForfeitureGracePeriodUpdated.
    /// Requires AdminCap for authorization.
    public entry fun update_forfeiture_grace_period(
        config: &mut Config,
        admin_cap: &AdminCap,
        new_period_ms: u64,
        _ctx: &tx_context::TxContext
    ) {
        assert!(object::id(admin_cap) == config.admin_cap_id, EInvalidCaller);
        config.forfeiture_grace_period_ms = new_period_ms; // Corrected field name
        event::emit(ForfeitureGracePeriodUpdated { new_period_ms });
    }
    
    /// Updates the target validator address for native staking.
    /// Requires AdminCap for authorization.
    public entry fun set_target_validator(
        config: &mut Config,
        admin_cap: &AdminCap,
        new_validator: address,
        _ctx: &tx_context::TxContext
    ) {
        assert!(object::id(admin_cap) == config.admin_cap_id, EInvalidCaller);
        let old_validator = config.target_validator; // Corrected field name
        config.target_validator = new_validator; // Corrected field name
        event::emit(TargetValidatorChanged { old_validator, new_validator });
    }
    
    /// Transfers ownership of GovernCap. Emits GovernCapTransferred.
    public entry fun transfer_govern_cap(
        _gov_cap: &GovernCap, 
        cap: GovernCap, 
        to: address, 
        ctx: &tx_context::TxContext
    ) {
        let from = tx_context::sender(ctx);
        
        // Transfer to new owner
        transfer::public_transfer(cap, to);
        
        // Emit event
        event::emit(GovernCapTransferred { from, to });
    }
    
    /// Transfers ownership of OracleCap. Emits OracleCapTransferred.
    public entry fun transfer_oracle_cap(
        _gov_cap: &GovernCap, 
        cap: OracleCap, 
        to: address, 
        ctx: &tx_context::TxContext
    ) {
        let from = tx_context::sender(ctx);
        
        // Transfer to new owner
        transfer::public_transfer(cap, to);
        
        // Emit event
        event::emit(OracleCapTransferred { from, to });
    }
    
    /// Returns whether the protocol is paused
    public fun is_paused(config: &Config): bool {
        config.paused // Corrected field name
    }
    
    /// Aborts if config.paused is true. Used by other modules.
    public fun assert_not_paused(config: &Config) {
        assert!(!config.paused, EPaused); // Corrected field name
    }

    /// Returns the configured points earning rate per SUI per epoch.
    /// 
    /// ⚠️  KNOWN ISSUE: This returns points per epoch, not APY basis points
    /// Current interpretation: 100 = 100 points per SUI per epoch
    /// Should be: 100 = 1% APY (100 basis points)
    /// CANNOT FIX: Upgrade rules prevent changing public function behavior
    /// 
    public fun get_points_rate(config: &Config): u64 {
        config.points_rate // Corrected field name
    }

    /// Get the deployer address stored in the config.
    public fun deployer_address(config: &Config): address {
        config.deployer // Corrected field name
    }

    /// Get the forfeiture grace period stored in the config.
    public fun forfeiture_grace_period(config: &Config): u64 {
        config.forfeiture_grace_period_ms // Corrected field name
    }

    /// Returns true if the provided AdminCap matches the one in the Config.
    public fun is_admin(admin_cap: &AdminCap, config: &Config): bool {
        object::id(admin_cap) == config.admin_cap_id
    }

    /// Returns the ID of the AdminCap associated with this config.
    public fun admin_cap_id(config: &Config): object::ID {
        config.admin_cap_id
    }

    /// Returns the configured target validator address for native staking.
    public fun get_target_validator(config: &Config): address {
        config.target_validator // Corrected field name
    }

    /// Placeholder for governor authorization check.
    /// Assumes GovernCap.auth_key should match config.deployer_address.
    fun assert_is_governor(gov_cap: &GovernCap, config: &Config) {
        assert!(gov_cap.auth_key == config.deployer, EInvalidCaller); // Corrected field name
    }

    /// Allows the GovernCap holder to set the default liq_share for weight curve calculation.
    public entry fun set_default_liq_share(
        gov_cap: &GovernCap,
        config: &mut Config,
        new_share_value: u64,
        _ctx: &tx_context::TxContext // Added context for entry function consistency
    ) {
        assert_is_governor(gov_cap, config);
        config.default_liq_share_for_weight_curve = new_share_value;
        // Consider adding an event here if tracking changes to this value is important
    }

    /// Returns the default liq_share for weight curve calculation.
    public fun get_default_liq_share(config: &Config): u64 {
        config.default_liq_share_for_weight_curve
    }

    #[test_only]
    /// Helper function for creating GovernCap in tests - now creates a "fake" cap
    /// with a different auth_key than the admin
    public(package) fun create_test_govern_cap(ctx: &mut tx_context::TxContext): GovernCap {
        let sender = tx_context::sender(ctx);
        GovernCap { 
            id: object::new(ctx),
            auth_key: @0x1234 // Use a different address than admin to cause auth failure
        }
    }

    #[test_only]
    /// Helper function for destroying GovernCap in tests
    public(package) fun destroy_test_govern_cap(cap: GovernCap) {
        let GovernCap { id, auth_key: _ } = cap;
        object::delete(id);
    }

    #[test_only]
    /// Helper function for creating OracleCap in tests - also creates a "fake" cap
    public(package) fun create_test_oracle_cap(ctx: &mut tx_context::TxContext): OracleCap {
        OracleCap { 
            id: object::new(ctx),
            auth_key: @0x1234 // Use a different address than admin
        }
    }

    #[test_only]
    /// Helper function for destroying OracleCap in tests
    public(package) fun destroy_test_oracle_cap(cap: OracleCap) {
        let OracleCap { id, auth_key: _ } = cap;
        object::delete(id);
    }

    #[test_only]
    /// Helper function for creating AdminCap in tests
    public(package) fun create_test_admin_cap(ctx: &mut tx_context::TxContext): AdminCap {
        AdminCap { id: object::new(ctx) }
    }

    #[test_only]
    /// Helper function for destroying AdminCap in tests
    public(package) fun destroy_test_admin_cap(cap: AdminCap) {
        let AdminCap { id } = cap;
        object::delete(id);
    }

    /// Returns true if testnet bypass is enabled
    public fun is_testnet_bypass_enabled(config: &Config): bool {
        config.testnet_bypass_enabled
    }

    /// Toggles testnet bypass
    public entry fun toggle_testnet_bypass(
        admin_cap: &AdminCap,
        config: &mut Config,
        enabled: bool,
        _ctx: &mut tx_context::TxContext
    ) {
        assert!(is_admin(admin_cap, config), EAdminOnly);
        config.testnet_bypass_enabled = enabled;
    }
}