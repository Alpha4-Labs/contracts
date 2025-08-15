#[allow(duplicate_alias, unused_use)]
/// Simplified Admin Module - B2B Platform Essentials Only
/// 
/// Core Features:
/// 1. FIXED ECONOMIC PARAMETERS - No governance needed for B2B platform
/// 2. SIMPLE EMERGENCY CONTROLS - Basic pause functionality
/// 3. TREASURY MANAGEMENT - Platform revenue address
/// 4. MINIMAL COMPLEXITY - Removed all governance, multi-sig, timelock systems
module alpha_points::admin_simple {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    
    // =================== CONSTANTS ===================
    
    // Fixed economic parameters (no governance needed)
    const POINTS_PER_USD: u64 = 1000;                // Fixed: 1 USD = 1000 Alpha Points
    const TREASURY_ADDRESS: address = @0x999999999999999999999999999999999999999999999999999999999999999;
    
    // =================== ERROR CONSTANTS ===================
    
    const EUnauthorized: u64 = 1;
    const EProtocolPaused: u64 = 2;
    
    // =================== STRUCTS ===================
    
    /// Simplified configuration - B2B platform essentials only
    public struct ConfigSimple has key {
        id: UID,
        
        // Economic parameters (FIXED - no governance needed)
        points_per_usd: u64,           // Fixed: 1000 points per $1 USD
        treasury_address: address,      // Platform treasury for revenue
        
        // Emergency controls (simple boolean flags)
        emergency_pause: bool,          // Global emergency pause
        mint_pause: bool,              // Pause point minting
        
        // Metadata
        last_updated_by: address,       // Last admin who made changes
    }
    
    /// Simple admin capability - no complex permissions
    public struct AdminCapSimple has key, store {
        id: UID,
        created_for: address,          // Admin address
    }
    
    // =================== EVENTS ===================
    
    public struct ConfigInitialized has copy, drop {
        admin: address,
        points_per_usd: u64,
        treasury_address: address,
    }
    
    public struct EmergencyPauseToggled has copy, drop {
        admin: address,
        emergency_pause: bool,
        mint_pause: bool,
    }
    
    public struct TreasuryUpdated has copy, drop {
        admin: address,
        old_treasury: address,
        new_treasury: address,
    }
    
    // =================== INITIALIZATION ===================
    
    /// Initialize the simplified admin system
    fun init(ctx: &mut TxContext) {
        let admin_address = tx_context::sender(ctx);
        
        // Create admin capability
        let admin_cap = AdminCapSimple {
            id: object::new(ctx),
            created_for: admin_address,
        };
        
        // Create simplified configuration
        let config = ConfigSimple {
            id: object::new(ctx),
            points_per_usd: POINTS_PER_USD,
            treasury_address: TREASURY_ADDRESS,
            emergency_pause: false,
            mint_pause: false,
            last_updated_by: admin_address,
        };
        
        // Transfer admin capability to deployer
        transfer::public_transfer(admin_cap, admin_address);
        
        // Share configuration object
        transfer::share_object(config);
        
        // Emit initialization event
        event::emit(ConfigInitialized {
            admin: admin_address,
            points_per_usd: POINTS_PER_USD,
            treasury_address: TREASURY_ADDRESS,
        });
    }
    
    // =================== VIEW FUNCTIONS ===================
    
    /// Get points per USD conversion rate
    public fun get_points_per_usd(config: &ConfigSimple): u64 {
        config.points_per_usd
    }
    
    /// Get treasury address
    public fun get_treasury_address(): address {
        TREASURY_ADDRESS
    }
    
    /// Check if protocol is paused
    public fun is_paused(config: &ConfigSimple): bool {
        config.emergency_pause
    }
    
    /// Check if minting is paused
    public fun is_mint_paused(config: &ConfigSimple): bool {
        config.emergency_pause || config.mint_pause
    }
    
    // =================== SAFETY ASSERTIONS ===================
    
    /// Assert protocol is not paused (used by other modules)
    public fun assert_not_paused(config: &ConfigSimple) {
        assert!(!config.emergency_pause, EProtocolPaused);
    }
    
    /// Assert minting is not paused (used by other modules)
    public fun assert_mint_not_paused(config: &ConfigSimple) {
        assert!(!config.emergency_pause && !config.mint_pause, EProtocolPaused);
    }
    
    // =================== AUTHORIZATION ===================
    
    /// Check if admin capability is valid (used by other modules)
    public fun is_admin(admin_cap: &AdminCapSimple, config: &ConfigSimple): bool {
        admin_cap.created_for == config.last_updated_by
    }
    
    // =================== ADMIN FUNCTIONS ===================
    
    /// Set emergency pause state
    public entry fun set_emergency_pause(
        config: &mut ConfigSimple,
        admin_cap: &AdminCapSimple,
        emergency_paused: bool,
        ctx: &mut TxContext
    ) {
        let admin = tx_context::sender(ctx);
        assert!(admin_cap.created_for == admin, EUnauthorized);
        
        config.emergency_pause = emergency_paused;
        config.last_updated_by = admin;
        
        event::emit(EmergencyPauseToggled {
            admin,
            emergency_pause: emergency_paused,
            mint_pause: config.mint_pause,
        });
    }
    
    /// Set mint pause state
    public entry fun set_mint_pause(
        config: &mut ConfigSimple,
        admin_cap: &AdminCapSimple,
        mint_paused: bool,
        ctx: &mut TxContext
    ) {
        let admin = tx_context::sender(ctx);
        assert!(admin_cap.created_for == admin, EUnauthorized);
        
        config.mint_pause = mint_paused;
        config.last_updated_by = admin;
        
        event::emit(EmergencyPauseToggled {
            admin,
            emergency_pause: config.emergency_pause,
            mint_pause: mint_paused,
        });
    }
    
    /// Update treasury address
    public entry fun set_treasury_address(
        config: &mut ConfigSimple,
        admin_cap: &AdminCapSimple,
        new_treasury: address,
        ctx: &mut TxContext
    ) {
        let admin = tx_context::sender(ctx);
        assert!(admin_cap.created_for == admin, EUnauthorized);
        
        let old_treasury = config.treasury_address;
        config.treasury_address = new_treasury;
        config.last_updated_by = admin;
        
        event::emit(TreasuryUpdated {
            admin,
            old_treasury,
            new_treasury,
        });
    }
    
    // =================== HELPER FUNCTIONS ===================
    
    /// Get admin capability ID (used by other modules)
    public fun get_admin_cap_id(admin_cap: &AdminCapSimple): ID {
        object::uid_to_inner(&admin_cap.id)
    }
    
    // =================== TEST-ONLY FUNCTIONS ===================
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
    
    #[test_only]
    public fun create_test_admin_cap(ctx: &mut TxContext): AdminCapSimple {
        AdminCapSimple {
            id: object::new(ctx),
            created_for: tx_context::sender(ctx),
        }
    }
    
    #[test_only]
    public fun create_test_config(ctx: &mut TxContext): ConfigSimple {
        ConfigSimple {
            id: object::new(ctx),
            points_per_usd: POINTS_PER_USD,
            treasury_address: TREASURY_ADDRESS,
            emergency_pause: false,
            mint_pause: false,
            last_updated_by: tx_context::sender(ctx),
        }
    }
    
    #[test_only]
    public fun destroy_test_admin_cap(cap: AdminCapSimple) {
        let AdminCapSimple { id, created_for: _ } = cap;
        object::delete(id);
    }
    
    #[test_only]
    public fun destroy_test_config(config: ConfigSimple) {
        let ConfigSimple { 
            id, 
            points_per_usd: _, 
            treasury_address: _, 
            emergency_pause: _, 
            mint_pause: _, 
            last_updated_by: _ 
        } = config;
        object::delete(id);
    }
}
