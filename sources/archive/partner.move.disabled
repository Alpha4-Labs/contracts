/// Module that manages capabilities for authorized partners.
module alpha_points::partner {
    // use sui::object; // Removed as it's a duplicate alias provided by default
    // use sui::tx_context; // Removed as it's a duplicate alias provided by default
    use sui::event;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use alpha_points::oracle::{Self, RateOracle, ExternalPriceOracle};
    
    use alpha_points::admin::AdminCap;
    // use sui::dynamic_field::{Self as df}; // Added for PartnerPerkStats linkage
    // use std::option::{Self as option, Option}; // This line will be removed
    // use alpha_points::perk_manager; // Removed to break cycle
    // Add kiosk-related imports
    use sui::kiosk::{Kiosk, KioskOwnerCap};
    // Add dynamic field support for upgrade-safe NFT collateral
    use sui::dynamic_field as df;
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};
    // Add USDC support

    use std::type_name::{Self, TypeName};

    /// Event for when partner settings are updated
    public struct PartnerSettingsUpdated has copy, drop {
        partner_cap_id: object::ID,
        paused: bool,
        daily_quota_pts: u64
    }
    
    /// Owned capability object for partners
    public struct PartnerCap has key, store {
        id: object::UID,
        partner_name: String,
        paused: bool,
        daily_quota_pts: u64,
        mint_remaining_today: u64,
        collateral_value_usdc_at_creation: u64,
        last_epoch: u64
    }
    
    // Events
    public struct PartnerCapGranted has copy, drop {
        id: object::ID,
        partner_address: address,
        partner_name: String
    }
    
    public struct PartnerCapCreatedWithCollateral has copy, drop {
        id: object::ID,
        partner_address: address,
        partner_name: String,
        collateral_sui_amount: u64,
        collateral_value_usdc: u64,
        daily_quota_pts: u64
    }
    
    public struct PartnerCapRevoked has copy, drop {
        id: object::ID,
        partner_name: String
    }
    
    public struct PartnerCapTransferred has copy, drop {
        id: object::ID,
        from: address,
        to: address,
        partner_name: String
    }
    
    /// NFT Bundle Collateral support structures
    public struct NFTCollateralInfo has store {
        collection_type: String,          // NFT collection identifier
        nft_ids: vector<object::ID>,      // IDs of NFTs in the bundle
        estimated_floor_value_usdc: u64,  // Estimated value based on floor price
        locked_timestamp: u64,            // When the collateral was locked
    }
    
    /// Dynamic field key for storing NFT collateral info on PartnerCap
    /// This allows us to attach NFT collateral data without modifying the PartnerCap struct
    public struct NFTCollateralKey has copy, drop, store { }
    
    /// NFT Collection Price Oracle - tracks floor prices for whitelisted collections
    public struct NFTCollectionOracle has key {
        id: object::UID,
        /// Maps collection_type -> floor_price_usdc
        floor_prices: Table<String, u64>,
        /// Maps collection_type -> last_update_epoch
        last_updates: Table<String, u64>,
        /// Maps collection_type -> price_feed_authority (who can update prices)
        price_authorities: Table<String, address>,
        /// Global settings
        max_price_staleness_epochs: u64, // Max epochs before price is considered stale
        auto_liquidation_enabled: bool,
    }
    
    /// Collection whitelist entry with risk parameters
    public struct CollectionInfo has store {
        collection_type: String,
        base_ltv: u64,              // Base LTV for this collection (in bps)
        liquidation_bonus: u64,     // Extra bonus for liquidators (in bps)
        min_floor_price_usdc: u64,  // Minimum floor price to accept
        is_active: bool,
    }
    
    /// Dynamic field key for storing collection whitelist
    public struct CollectionWhitelistKey has copy, drop, store { }
    
    /// Event for when a PartnerCap is created with NFT bundle collateral
    public struct PartnerCapCreatedWithNFTBundle has copy, drop {
        id: object::ID,
        partner_address: address,
        partner_name: String,
        nft_bundle_count: u64,
        estimated_bundle_value_usdc: u64,
        daily_quota_pts: u64,
        kiosk_id: object::ID
    }
    
    /// Event for when NFT collateral is released/withdrawn
    public struct NFTCollateralReleased has copy, drop {
        partner_cap_id: object::ID,
        partner_address: address,
        nft_count: u64,
        released_value_usdc: u64,
        kiosk_id: object::ID
    }
    
    /// Event for when NFT collateral is liquidated due to health factor
    public struct NFTCollateralLiquidated has copy, drop {
        partner_cap_id: object::ID,
        partner_address: address,
        liquidator: address,
        nft_count: u64,
        liquidated_value_usdc: u64,
        health_factor: u64
    }
    
    /// Event for when NFT collateral health factor is checked
    public struct NFTHealthFactorUpdated has copy, drop {
        partner_cap_id: object::ID,
        old_health_factor: u64,
        new_health_factor: u64,
        current_value_usdc: u64,
        outstanding_quota_used: u64
    }
    
    /// Event for when NFT floor price is updated by oracle
    public struct NFTFloorPriceUpdated has copy, drop {
        collection_type: String,
        old_price_usdc: u64,
        new_price_usdc: u64,
        update_epoch: u64,
        price_authority: address
    }
    
    /// Event for when a collection is added to whitelist
    public struct CollectionWhitelisted has copy, drop {
        collection_type: String,
        base_ltv: u64,
        liquidation_bonus: u64,
        min_floor_price_usdc: u64
    }
    
    /// Event for automated quota adjustment based on price changes
    public struct QuotaAutoAdjusted has copy, drop {
        partner_cap_id: object::ID,
        collection_type: String,
        old_quota: u64,
        new_quota: u64,
        price_change_percent: u64,
        new_health_factor: u64
    }
    
    /// Event for batch SUI quota adjustments
    public struct SUIQuotaBatchAdjustment has copy, drop {
        updated_partners: vector<object::ID>,
        updated_count: u64,
        trigger_epoch: u64,
        current_sui_rate: u128,
        rate_decimals: u8,
        updated_by: address
    }
    
    /// ProxyCap struct - MUST match live version exactly for upgrade compatibility
    public struct ProxyCap<SuiNSNft: key + store> has key, store {
        id: object::UID,
        owner_address: address,
        partner_cap_id: object::ID,         // ← Must match live version field name
        suins_parent_nft_object: SuiNSNft  // ← Must store actual object, not just ID
    }
    
    /// Event emitted when a new ProxyCap is created.
    public struct ProxyCapCreated has copy, drop {
        proxy_cap_id: object::ID,
        partner_cap_id: object::ID,
        owner_address: address,
        suins_parent_nft_id: object::ID
    }
    
    /// USDC Collateral support structures (upgrade-safe via dynamic fields)
    public struct USDCCollateralInfo has store, drop {
        usdc_amount_deposited: u64,       // Original USDC amount deposited
        deposit_timestamp: u64,           // When the collateral was deposited
        collateral_asset_type: TypeName, // Store the exact USDC coin type for type safety
    }
    
    /// Dynamic field key for storing USDC collateral info on PartnerCap
    public struct USDCCollateralKey has copy, drop, store { }

    /// Event for when a PartnerCap is created with USDC collateral
    public struct PartnerCapCreatedWithUSDCCollateral has copy, drop {
        id: object::ID,
        partner_address: address,
        partner_name: String,
        usdc_amount: u64,
        collateral_value_usdc: u64, // Should equal usdc_amount for USDC
        daily_quota_pts: u64,
        usdc_coin_type: TypeName
    }
    
    /// Event for when USDC collateral is withdrawn/released
    public struct USDCCollateralReleased has copy, drop {
        partner_cap_id: object::ID,
        partner_address: address,
        usdc_amount: u64,
        release_timestamp: u64
    }
    
    // CONSTANTS
    const E_COLLATERAL_VALUE_ZERO: u64 = 101;
    const POINTS_QUOTA_PER_USDC_COLLATERAL_UNIT: u64 = 1000; // Example: 1 USDC collateral value = 1000 daily points quota
    
    // NFT Bundle Collateral Constants
    const E_EMPTY_NFT_BUNDLE: u64 = 102;
    const E_NFT_VALUATION_FAILED: u64 = 104;
    const NFT_COLLATERAL_LTV_RATIO: u64 = 7000; // 70% LTV for NFT collateral (more conservative than SUI)
    const MIN_NFT_BUNDLE_SIZE: u64 = 1;
    
    // Additional NFT collateral constants
    #[allow(unused_const)]
    const E_COLLATERAL_LOCKED: u64 = 105;
    const E_HEALTH_FACTOR_TOO_LOW: u64 = 106;
    #[allow(unused_const)]
    const E_INSUFFICIENT_COLLATERAL_FOR_QUOTA: u64 = 107;
    #[allow(unused_const)]
    const E_KIOSK_NOT_OWNED: u64 = 108;
    const MIN_HEALTH_FACTOR: u64 = 12000; // 120% minimum health factor (1.2x coverage)
    const LIQUIDATION_THRESHOLD: u64 = 11000; // 110% liquidation threshold
    const MAX_BUNDLE_SIZE: u64 = 50; // Maximum NFTs per bundle to prevent gas issues
    const E_INVALID_BATCH_DATA: u64 = 109;
    
    // Oracle and automation constants
    const E_COLLECTION_NOT_WHITELISTED: u64 = 110;
    const E_PRICE_TOO_STALE: u64 = 111;
    const E_UNAUTHORIZED_PRICE_FEED: u64 = 112;
    const E_FLOOR_PRICE_TOO_LOW: u64 = 113;
    const MAX_PRICE_STALENESS_EPOCHS: u64 = 24; // 24 epochs = ~1 day
    const MIN_COLLECTION_FLOOR_PRICE: u64 = 100; // $1.00 minimum floor price
    const PRICE_UPDATE_THRESHOLD_BPS: u64 = 500; // 5% price change triggers quota adjustment
    
    // === Core module functions ===
    
    /// Creates PartnerCap via collateral deposit (permissionless)
    /// The SUI collateral is consumed (burned) to activate the PartnerCap.
    public entry fun create_partner_cap_with_collateral(
        sui_collateral: Coin<SUI>,
        rate_oracle: &RateOracle,
        partner_name: String,
        ctx: &mut tx_context::TxContext
    ) {
        let partner_address = tx_context::sender(ctx);
        let current_epoch = tx_context::epoch(ctx);
        let sui_collateral_amount = coin::value(&sui_collateral);

        // Use the oracle to get the value of SUI in USDC (or a base unit the oracle provides)
        let collateral_value_usdc = oracle::price_in_usdc(rate_oracle, sui_collateral_amount);
        assert!(collateral_value_usdc > 0, E_COLLATERAL_VALUE_ZERO);

        // Determine daily_quota_pts based on collateral_value_usdc
        let daily_quota = collateral_value_usdc * POINTS_QUOTA_PER_USDC_COLLATERAL_UNIT;

        let cap_id = object::new(ctx);

        let partner_cap = PartnerCap {
            id: cap_id,
            partner_name: partner_name,
            paused: false,
            daily_quota_pts: daily_quota,
            mint_remaining_today: daily_quota,
            collateral_value_usdc_at_creation: collateral_value_usdc,
            last_epoch: current_epoch,
        };

        event::emit(PartnerCapCreatedWithCollateral {
            id: object::uid_to_inner(&partner_cap.id),
            partner_address,
            partner_name: partner_name,
            collateral_sui_amount: sui_collateral_amount,
            collateral_value_usdc,
            daily_quota_pts: daily_quota
        });

        // Consume the SUI collateral by transferring it to the zero address (burn).
        transfer::public_transfer(sui_collateral, @0x0);

        transfer::public_transfer(partner_cap, partner_address);
    }
    
    /// Creates PartnerCap via NFT bundle collateral (permissionless)
    /// NFTs remain in the user's kiosk but are locked as collateral
    /// Uses a more conservative LTV ratio for NFT collateral vs SUI
    public entry fun create_partner_cap_with_nft_bundle(
        kiosk: &mut Kiosk,
        _kiosk_owner_cap: &KioskOwnerCap,
        nft_ids: vector<object::ID>,
        collection_type: String,
        estimated_floor_value_usdc: u64,
        _rate_oracle: &RateOracle,
        partner_name: String,
        ctx: &mut tx_context::TxContext
    ) {
        let partner_address = tx_context::sender(ctx);
        let current_epoch = tx_context::epoch(ctx);
        let bundle_size = vector::length(&nft_ids);
        
        // Validate inputs
        assert!(bundle_size >= MIN_NFT_BUNDLE_SIZE, E_EMPTY_NFT_BUNDLE);
        assert!(estimated_floor_value_usdc > 0, E_NFT_VALUATION_FAILED);
        
        // Additional validations for production safety
        assert!(bundle_size <= MAX_BUNDLE_SIZE, E_INVALID_BATCH_DATA);
        
        // TODO: Integrate with NFT Collection Oracle to validate collection and get current floor price
        // For now, we'll keep the manual estimation but this should be replaced with:
        // let current_floor_price = get_current_floor_price(nft_oracle, collection_type, clock);
        // assert!(estimated_floor_value_usdc >= current_floor_price * bundle_size, E_FLOOR_PRICE_TOO_LOW);
        
        // Verify kiosk ownership (the kiosk owner should be the same as the caller)
        // Note: In practice, you'd want additional verification that the NFTs are actually in the kiosk
        // and that the floor value estimation is reasonable (could integrate with NFT price oracles)
        
        // Calculate daily quota with conservative LTV
        let effective_collateral_value = (estimated_floor_value_usdc * NFT_COLLATERAL_LTV_RATIO) / 10000;
        let daily_quota = effective_collateral_value * POINTS_QUOTA_PER_USDC_COLLATERAL_UNIT;
        
        let cap_id = object::new(ctx);
        
        // Create NFT collateral info
        let nft_collateral_info = NFTCollateralInfo {
            collection_type,
            nft_ids,
            estimated_floor_value_usdc,
            locked_timestamp: current_epoch,
        };
        
        let mut partner_cap = PartnerCap {
            id: cap_id,
            partner_name: partner_name,
            paused: false,
            daily_quota_pts: daily_quota,
            mint_remaining_today: daily_quota,
            collateral_value_usdc_at_creation: effective_collateral_value,
            last_epoch: current_epoch
        };
        
        // Store NFT collateral info as a dynamic field (upgrade-safe approach)
        df::add(&mut partner_cap.id, NFTCollateralKey {}, nft_collateral_info);
        
        event::emit(PartnerCapCreatedWithNFTBundle {
            id: object::uid_to_inner(&partner_cap.id),
            partner_address,
            partner_name: partner_name,
            nft_bundle_count: bundle_size,
            estimated_bundle_value_usdc: estimated_floor_value_usdc,
            daily_quota_pts: daily_quota,
            kiosk_id: object::id(kiosk)
        });
        
        // TODO: Implement actual NFT locking mechanism in kiosk
        // This would typically involve:
        // 1. Verifying NFTs are actually in the kiosk
        // 2. Locking them so they cannot be transferred
        // 3. Setting up mechanisms for liquidation if needed
        
        transfer::public_transfer(partner_cap, partner_address);
    }
    
    /// Creates PartnerCap, transfers to partner_address
    public entry fun grant_partner_cap(
        _admin_cap: &AdminCap,
        partner_address: address,
        name: String,
        ctx: &mut tx_context::TxContext
    ) {
        let id = object::new(ctx);
        let current_epoch = tx_context::epoch(ctx);
        
        // Create partner capability
        let partner_cap = PartnerCap {
            id,
            partner_name: name,
            paused: false,
            daily_quota_pts: 0,
            mint_remaining_today: 0,
            collateral_value_usdc_at_creation: 0,
            last_epoch: current_epoch,
        };
        
        // Emit event
        event::emit(PartnerCapGranted {
            id: object::uid_to_inner(&partner_cap.id),
            partner_address,
            partner_name: name
        });
        
        // Transfer to partner
        transfer::public_transfer(partner_cap, partner_address);
    }
    
    /// Destroys the partner capability
    public entry fun revoke_partner_cap(
        _admin_cap: &AdminCap,
        cap: PartnerCap,
        _ctx: &mut tx_context::TxContext
    ) {
        let PartnerCap {
            id,
            partner_name,
            collateral_value_usdc_at_creation: _collateral_value_usdc_at_creation,
            daily_quota_pts: _daily_quota_pts,
            mint_remaining_today: _mint_remaining_today,
            paused: _paused,
            last_epoch: _last_epoch,
        } = cap;
        
        // Emit event
        event::emit(PartnerCapRevoked {
            id: object::uid_to_inner(&id),
            partner_name
        });
        
        // Delete the object
        object::delete(id);
    }
    
    /// Transfers existing partner capability
    public entry fun transfer_partner_cap(
        cap: PartnerCap,
        to: address,
        ctx: &mut tx_context::TxContext
    ) {
        let from = tx_context::sender(ctx);
        
        // Emit event
        event::emit(PartnerCapTransferred {
            id: object::uid_to_inner(&cap.id),
            from,
            to,
            partner_name: cap.partner_name
        });
        
        // Transfer to new owner
        transfer::public_transfer(cap, to);
    }
    
    /// Creates ProxyCap - MUST match live version exactly for upgrade compatibility
    public entry fun create_proxy_cap<SuiNSNft: key + store>(
        partner_cap: &PartnerCap,
        suins_parent_nft: SuiNSNft,
        ctx: &mut tx_context::TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let proxy_cap_uid = object::new(ctx);

        let suins_nft_id_for_event = object::id(&suins_parent_nft);

        let new_proxy_cap = ProxyCap<SuiNSNft> {
            id: proxy_cap_uid,
            owner_address: sender,
            partner_cap_id: object::id(partner_cap),    // ← Must match live field name
            suins_parent_nft_object: suins_parent_nft   // ← Must store actual object
        };

        event::emit(ProxyCapCreated {
            proxy_cap_id: object::uid_to_inner(&new_proxy_cap.id),
            partner_cap_id: object::id(partner_cap),
            owner_address: sender,
            suins_parent_nft_id: suins_nft_id_for_event
        });

        transfer::public_transfer(new_proxy_cap, sender);
    }
    
    /// Returns the partner name
    public fun get_partner_name(cap: &PartnerCap): String {
        cap.partner_name
    }
    
    /// Returns a reference to the UID (id) of the PartnerCap
    public fun get_id(cap: &PartnerCap): &object::UID {
        &cap.id
    }
    
    // Added for integration.move
    public fun get_paused(cap: &PartnerCap): bool {
        cap.paused
    }
    
    /// Returns the last epoch when mint_remaining_today was reset
    public fun get_last_epoch(cap: &PartnerCap): u64 {
        cap.last_epoch
    }
    
    /// Resets mint_remaining_today to daily_quota_pts and updates last_epoch
    public fun reset_mint_today_mut(partner: &mut PartnerCap, current_epoch: u64) {
        partner.mint_remaining_today = partner.daily_quota_pts;
        partner.last_epoch = current_epoch;
    }
    
    // Renamed and updated for integration.move (removed assertion)
    public fun decrease_mint_remaining_today_mut(partner: &mut PartnerCap, pts: u64) {
        if (partner.mint_remaining_today >= pts) {
            partner.mint_remaining_today = partner.mint_remaining_today - pts;
        } else {
            partner.mint_remaining_today = 0; // Prevent underflow
        };
    }
    
    public fun get_daily_quota_pts(partner: &PartnerCap): u64 {
        partner.daily_quota_pts
    }
    
    public fun get_mint_remaining_today(partner: &PartnerCap): u64 {
        partner.mint_remaining_today
    }
    
    // Admin function to set partner pause status
    public entry fun set_partner_paused(
        _admin_cap: &AdminCap,
        cap: &mut PartnerCap,
        paused_status: bool,
        _ctx: &mut tx_context::TxContext // Context for event emission or future use
    ) {
        cap.paused = paused_status;
        event::emit(PartnerSettingsUpdated {
            partner_cap_id: object::uid_to_inner(&cap.id),
            paused: cap.paused,
            daily_quota_pts: cap.daily_quota_pts
        });
    }
    
    // Admin function to set partner daily quota
    public entry fun set_partner_daily_quota(
        _admin_cap: &AdminCap,
        cap: &mut PartnerCap,
        new_quota: u64,
        _ctx: &mut tx_context::TxContext // Context for event emission or future use
    ) {
        cap.daily_quota_pts = new_quota;
        event::emit(PartnerSettingsUpdated {
            partner_cap_id: object::uid_to_inner(&cap.id),
            paused: cap.paused,
            daily_quota_pts: cap.daily_quota_pts
        });
    }

    // === NFT Collateral Management Functions ===
    
    /// Returns whether the PartnerCap has NFT collateral
    public fun has_nft_collateral(cap: &PartnerCap): bool {
        df::exists_(&cap.id, NFTCollateralKey {})
    }
    
    /// Returns the NFT bundle count for this PartnerCap (0 if no NFT collateral)
    public fun get_nft_bundle_count(cap: &PartnerCap): u64 {
        if (df::exists_(&cap.id, NFTCollateralKey {})) {
            let collateral_info = df::borrow<NFTCollateralKey, NFTCollateralInfo>(&cap.id, NFTCollateralKey {});
            vector::length(&collateral_info.nft_ids)
        } else {
            0
        }
    }
    
    /// Returns the collection type for NFT collateral (empty string if none)
    public fun get_nft_collection_type(cap: &PartnerCap): String {
        if (df::exists_(&cap.id, NFTCollateralKey {})) {
            let collateral_info = df::borrow<NFTCollateralKey, NFTCollateralInfo>(&cap.id, NFTCollateralKey {});
            collateral_info.collection_type
        } else {
            std::string::utf8(b"")
        }
    }
    
    /// Returns the estimated floor value used at creation (0 if no NFT collateral)
    public fun get_nft_estimated_value(cap: &PartnerCap): u64 {
        if (df::exists_(&cap.id, NFTCollateralKey {})) {
            let collateral_info = df::borrow<NFTCollateralKey, NFTCollateralInfo>(&cap.id, NFTCollateralKey {});
            collateral_info.estimated_floor_value_usdc
        } else {
            0
        }
    }
    
    /// Admin function to update NFT collateral valuation (for revaluation scenarios)
    public entry fun revalue_nft_collateral(
        _admin_cap: &AdminCap,
        cap: &mut PartnerCap,
        new_estimated_value_usdc: u64,
        _ctx: &mut tx_context::TxContext
    ) {
        assert!(df::exists_(&cap.id, NFTCollateralKey {}), E_NFT_VALUATION_FAILED);
        
        let collateral_info = df::borrow_mut<NFTCollateralKey, NFTCollateralInfo>(&mut cap.id, NFTCollateralKey {});
        collateral_info.estimated_floor_value_usdc = new_estimated_value_usdc;
        
        // Recalculate daily quota based on new valuation
        let effective_collateral_value = (new_estimated_value_usdc * NFT_COLLATERAL_LTV_RATIO) / 10000;
        let new_daily_quota = effective_collateral_value * POINTS_QUOTA_PER_USDC_COLLATERAL_UNIT;
        
        cap.daily_quota_pts = new_daily_quota;
        cap.collateral_value_usdc_at_creation = effective_collateral_value;
        
        event::emit(PartnerSettingsUpdated {
            partner_cap_id: object::uid_to_inner(&cap.id),
            paused: cap.paused,
            daily_quota_pts: cap.daily_quota_pts
        });
    }

    /// Calculate health factor for NFT collateral (returns 10000 = 100%)
    /// Health factor = (collateral_value / quota_value_used) * 10000
    public fun calculate_health_factor(cap: &PartnerCap): u64 {
        if (!df::exists_(&cap.id, NFTCollateralKey {})) {
            return 10000 // No NFT collateral, return neutral health factor
        };
        
        let collateral_info = df::borrow<NFTCollateralKey, NFTCollateralInfo>(&cap.id, NFTCollateralKey {});
        let effective_collateral = (collateral_info.estimated_floor_value_usdc * NFT_COLLATERAL_LTV_RATIO) / 10000;
        
        // Calculate how much quota has been "used" based on outstanding daily quota
        let quota_value_used = cap.collateral_value_usdc_at_creation;
        
        if (quota_value_used == 0) {
            return 99999 // Max health factor if no quota used
        };
        
        (effective_collateral * 10000) / quota_value_used
    }
    
    /// Get the NFT IDs from collateral (returns empty vector if no NFT collateral)
    public fun get_nft_ids(cap: &PartnerCap): vector<object::ID> {
        if (df::exists_(&cap.id, NFTCollateralKey {})) {
            let collateral_info = df::borrow<NFTCollateralKey, NFTCollateralInfo>(&cap.id, NFTCollateralKey {});
            collateral_info.nft_ids
        } else {
            vector::empty<object::ID>()
        }
    }
    
    /// Get the locked timestamp for NFT collateral
    public fun get_nft_locked_timestamp(cap: &PartnerCap): u64 {
        if (df::exists_(&cap.id, NFTCollateralKey {})) {
            let collateral_info = df::borrow<NFTCollateralKey, NFTCollateralInfo>(&cap.id, NFTCollateralKey {});
            collateral_info.locked_timestamp
        } else {
            0
        }
    }
    
    /// Check if NFT collateral can be safely released (health factor above threshold)
    public fun can_release_nft_collateral(cap: &PartnerCap): bool {
        if (!has_nft_collateral(cap)) {
            return false
        };
        calculate_health_factor(cap) >= MIN_HEALTH_FACTOR
    }
    
    /// User function to release NFT collateral when health factor is good
    /// This allows partners to unlock their NFTs when they've paid down quota usage
    public entry fun release_nft_collateral(
        cap: &mut PartnerCap,
        kiosk: &mut Kiosk,
        _kiosk_owner_cap: &KioskOwnerCap,
        ctx: &mut tx_context::TxContext
    ) {
        let caller = tx_context::sender(ctx);
        assert!(df::exists_(&cap.id, NFTCollateralKey {}), E_NFT_VALUATION_FAILED);
        
        // Check health factor is sufficient for release
        let health_factor = calculate_health_factor(cap);
        assert!(health_factor >= MIN_HEALTH_FACTOR, E_HEALTH_FACTOR_TOO_LOW);
        
        // Remove collateral info
        let collateral_info = df::remove<NFTCollateralKey, NFTCollateralInfo>(&mut cap.id, NFTCollateralKey {});
        let nft_count = vector::length(&collateral_info.nft_ids);
        
        // Reset quota to zero since collateral is being removed
        cap.daily_quota_pts = 0;
        cap.mint_remaining_today = 0;
        cap.collateral_value_usdc_at_creation = 0;
        
        // Emit release event
        event::emit(NFTCollateralReleased {
            partner_cap_id: object::uid_to_inner(&cap.id),
            partner_address: caller,
            nft_count,
            released_value_usdc: collateral_info.estimated_floor_value_usdc,
            kiosk_id: object::id(kiosk)
        });
        
        // TODO: Implement actual NFT unlocking in kiosk
        // This would involve calling kiosk::delist or similar functions
        // to release the locked NFTs back to the owner
        
        // Clean up the collateral info
        let NFTCollateralInfo {
            collection_type: _,
            nft_ids: _,
            estimated_floor_value_usdc: _,
            locked_timestamp: _
        } = collateral_info;
    }
    
    /// Admin function for emergency liquidation of unhealthy NFT collateral
    public entry fun liquidate_nft_collateral(
        _admin_cap: &AdminCap,
        cap: &mut PartnerCap,
        new_estimated_value_usdc: u64,
        liquidator: address,
        ctx: &mut tx_context::TxContext
    ) {
        assert!(df::exists_(&cap.id, NFTCollateralKey {}), E_NFT_VALUATION_FAILED);
        
        // Update valuation first
        let collateral_info = df::borrow_mut<NFTCollateralKey, NFTCollateralInfo>(&mut cap.id, NFTCollateralKey {});
        collateral_info.estimated_floor_value_usdc = new_estimated_value_usdc;
        
        // Check if liquidation is warranted
        let health_factor = calculate_health_factor(cap);
        assert!(health_factor < LIQUIDATION_THRESHOLD, E_HEALTH_FACTOR_TOO_LOW);
        
        // Remove collateral and reset quotas
        let removed_collateral = df::remove<NFTCollateralKey, NFTCollateralInfo>(&mut cap.id, NFTCollateralKey {});
        let nft_count = vector::length(&removed_collateral.nft_ids);
        
        // Severely reduce quotas as penalty
        cap.daily_quota_pts = cap.daily_quota_pts / 4; // Reduce to 25%
        cap.mint_remaining_today = 0;
        cap.collateral_value_usdc_at_creation = cap.collateral_value_usdc_at_creation / 4;
        
        // Emit liquidation event
        event::emit(NFTCollateralLiquidated {
            partner_cap_id: object::uid_to_inner(&cap.id),
            partner_address: tx_context::sender(ctx),
            liquidator,
            nft_count,
            liquidated_value_usdc: removed_collateral.estimated_floor_value_usdc,
            health_factor
        });
        
        // Clean up
        let NFTCollateralInfo {
            collection_type: _,
            nft_ids: _,
            estimated_floor_value_usdc: _,
            locked_timestamp: _
        } = removed_collateral;
    }
    
    /// Batch update multiple PartnerCaps with new valuations (admin function)
    public fun batch_revalue_nft_collateral(
        _admin_cap: &AdminCap,
        caps: &mut vector<PartnerCap>,
        new_values: vector<u64>,
        _ctx: &mut tx_context::TxContext
    ) {
        assert!(vector::length(caps) == vector::length(&new_values), E_INVALID_BATCH_DATA);
        
        let mut i = 0;
        let len = vector::length(caps);
        
        while (i < len) {
            let cap = vector::borrow_mut(caps, i);
            let new_value = *vector::borrow(&new_values, i);
            
            if (df::exists_(&cap.id, NFTCollateralKey {})) {
                let collateral_info = df::borrow_mut<NFTCollateralKey, NFTCollateralInfo>(&mut cap.id, NFTCollateralKey {});
                let old_value = collateral_info.estimated_floor_value_usdc;
                collateral_info.estimated_floor_value_usdc = new_value;
                
                // Recalculate quota
                let effective_collateral_value = (new_value * NFT_COLLATERAL_LTV_RATIO) / 10000;
                let new_daily_quota = effective_collateral_value * POINTS_QUOTA_PER_USDC_COLLATERAL_UNIT;
                
                cap.daily_quota_pts = new_daily_quota;
                cap.collateral_value_usdc_at_creation = effective_collateral_value;
                
                // Emit health factor update
                let old_health_factor = (old_value * NFT_COLLATERAL_LTV_RATIO * 10000) / (cap.collateral_value_usdc_at_creation * 10000);
                let new_health_factor = calculate_health_factor(cap);
                
                event::emit(NFTHealthFactorUpdated {
                    partner_cap_id: object::uid_to_inner(&cap.id),
                    old_health_factor,
                    new_health_factor,
                    current_value_usdc: new_value,
                    outstanding_quota_used: cap.collateral_value_usdc_at_creation
                });
            };
            
            i = i + 1;
        }
    }

    /// Admin function to remove NFT collateral (for liquidation or release scenarios)
    /// Returns the NFT collateral info that was removed
    public fun remove_nft_collateral(
        _admin_cap: &AdminCap,
        cap: &mut PartnerCap
    ): NFTCollateralInfo {
        assert!(df::exists_(&cap.id, NFTCollateralKey {}), E_NFT_VALUATION_FAILED);
        df::remove<NFTCollateralKey, NFTCollateralInfo>(&mut cap.id, NFTCollateralKey {})
    }

    /// Get comprehensive NFT collateral status for monitoring/dashboard purposes
    public fun get_nft_collateral_status(cap: &PartnerCap): (bool, u64, u64, u64, u64, u64) {
        if (!df::exists_(&cap.id, NFTCollateralKey {})) {
            return (false, 0, 0, 0, 10000, 0) // has_nft, count, value, timestamp, health_factor, quota
        };
        
        let collateral_info = df::borrow<NFTCollateralKey, NFTCollateralInfo>(&cap.id, NFTCollateralKey {});
        let nft_count = vector::length(&collateral_info.nft_ids);
        let health_factor = calculate_health_factor(cap);
        
        (
            true,
            nft_count,
            collateral_info.estimated_floor_value_usdc,
            collateral_info.locked_timestamp,
            health_factor,
            cap.daily_quota_pts
        )
    }
    
    /// Check if a PartnerCap is at risk of liquidation
    public fun is_at_liquidation_risk(cap: &PartnerCap): bool {
        if (!has_nft_collateral(cap)) {
            return false
        };
        calculate_health_factor(cap) <= LIQUIDATION_THRESHOLD
    }
    
    /// Get the current effective LTV ratio for a PartnerCap with NFT collateral
    public fun get_effective_ltv(cap: &PartnerCap): u64 {
        if (!df::exists_(&cap.id, NFTCollateralKey {})) {
            return 0
        };
        
        let collateral_info = df::borrow<NFTCollateralKey, NFTCollateralInfo>(&cap.id, NFTCollateralKey {});
        let total_collateral_value = collateral_info.estimated_floor_value_usdc;
        let quota_value = cap.collateral_value_usdc_at_creation;
        
        if (total_collateral_value == 0) {
            return 10000 // 100% if no collateral
        };
        
        (quota_value * 10000) / total_collateral_value
    }

    // --- ProxyCap Functions - MUST match live version exactly ---

    /// Returns the UID of the ProxyCap.
    public fun get_proxy_cap_id<SuiNSNft: key + store>(proxy_cap: &ProxyCap<SuiNSNft>): &object::UID {
        &proxy_cap.id
    }

    /// Returns the owner address of the ProxyCap.
    public fun get_proxy_cap_owner_address<SuiNSNft: key + store>(proxy_cap: &ProxyCap<SuiNSNft>): address {
        proxy_cap.owner_address
    }

    /// Returns an immutable reference to the SuiNS parent NFT object held by the ProxyCap.
    public fun get_proxy_cap_suins_parent_nft_object_ref<SuiNSNft: key + store>(proxy_cap: &ProxyCap<SuiNSNft>): &SuiNSNft {
        &proxy_cap.suins_parent_nft_object
    }

    /// Returns a mutable reference to the SuiNS parent NFT object held by the ProxyCap.
    public fun get_proxy_cap_suins_parent_nft_object_mut<SuiNSNft: key + store>(proxy_cap: &mut ProxyCap<SuiNSNft>): &mut SuiNSNft {
        &mut proxy_cap.suins_parent_nft_object
    }

    /// Initialize the NFT Collection Oracle (called once by admin)
    public entry fun init_nft_collection_oracle(
        _admin_cap: &AdminCap,
        ctx: &mut tx_context::TxContext
    ) {
        let mut oracle = NFTCollectionOracle {
            id: object::new(ctx),
            floor_prices: table::new(ctx),
            last_updates: table::new(ctx),
            price_authorities: table::new(ctx),
            max_price_staleness_epochs: MAX_PRICE_STALENESS_EPOCHS,
            auto_liquidation_enabled: true,
        };
        
        // Add collection whitelist as dynamic field
        df::add(&mut oracle.id, CollectionWhitelistKey {}, table::new<String, CollectionInfo>(ctx));
        
        transfer::share_object(oracle);
    }
    
    /// Add a collection to the whitelist with risk parameters
    public entry fun whitelist_collection(
        _admin_cap: &AdminCap,
        oracle: &mut NFTCollectionOracle,
        collection_type: String,
        base_ltv: u64,
        liquidation_bonus: u64,
        min_floor_price_usdc: u64,
        price_authority: address,
        _ctx: &mut tx_context::TxContext
    ) {
        // Validate parameters
        assert!(base_ltv <= 8000, E_INVALID_BATCH_DATA); // Max 80% LTV
        assert!(liquidation_bonus <= 2000, E_INVALID_BATCH_DATA); // Max 20% bonus
        assert!(min_floor_price_usdc >= MIN_COLLECTION_FLOOR_PRICE, E_FLOOR_PRICE_TOO_LOW);
        
        // Add to whitelist
        let whitelist = df::borrow_mut<CollectionWhitelistKey, Table<String, CollectionInfo>>(
            &mut oracle.id, 
            CollectionWhitelistKey {}
        );
        
        let collection_info = CollectionInfo {
            collection_type: collection_type,
            base_ltv,
            liquidation_bonus,
            min_floor_price_usdc,
            is_active: true,
        };
        
        table::add(whitelist, collection_type, collection_info);
        table::add(&mut oracle.price_authorities, collection_type, price_authority);
        
        event::emit(CollectionWhitelisted {
            collection_type,
            base_ltv,
            liquidation_bonus,
            min_floor_price_usdc
        });
    }
    
    /// Update floor price for a collection (called by authorized price feeds)
    public entry fun update_floor_price(
        oracle: &mut NFTCollectionOracle,
        collection_type: String,
        new_floor_price_usdc: u64,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        let caller = tx_context::sender(ctx);
        let current_epoch = clock::timestamp_ms(clock) / (24 * 60 * 60 * 1000); // Convert to days
        
        // Verify caller is authorized for this collection
        assert!(table::contains(&oracle.price_authorities, collection_type), E_COLLECTION_NOT_WHITELISTED);
        let authorized_caller = table::borrow(&oracle.price_authorities, collection_type);
        assert!(caller == *authorized_caller, E_UNAUTHORIZED_PRICE_FEED);
        
        // Validate new price meets minimum
        let whitelist = df::borrow<CollectionWhitelistKey, Table<String, CollectionInfo>>(
            &oracle.id, 
            CollectionWhitelistKey {}
        );
        let collection_info = table::borrow(whitelist, collection_type);
        assert!(new_floor_price_usdc >= collection_info.min_floor_price_usdc, E_FLOOR_PRICE_TOO_LOW);
        
        // Get old price for event
        let old_price = if (table::contains(&oracle.floor_prices, collection_type)) {
            *table::borrow(&oracle.floor_prices, collection_type)
        } else {
            0
        };
        
        // Update price and timestamp
        if (table::contains(&oracle.floor_prices, collection_type)) {
            *table::borrow_mut(&mut oracle.floor_prices, collection_type) = new_floor_price_usdc;
            *table::borrow_mut(&mut oracle.last_updates, collection_type) = current_epoch;
        } else {
            table::add(&mut oracle.floor_prices, collection_type, new_floor_price_usdc);
            table::add(&mut oracle.last_updates, collection_type, current_epoch);
        };
        
        event::emit(NFTFloorPriceUpdated {
            collection_type,
            old_price_usdc: old_price,
            new_price_usdc: new_floor_price_usdc,
            update_epoch: current_epoch,
            price_authority: caller
        });
    }
    
    /// Get current floor price for a collection (with staleness check)
    public fun get_current_floor_price(
        oracle: &NFTCollectionOracle,
        collection_type: String,
        clock: &Clock
    ): u64 {
        let current_epoch = clock::timestamp_ms(clock) / (24 * 60 * 60 * 1000);
        
        assert!(table::contains(&oracle.floor_prices, collection_type), E_COLLECTION_NOT_WHITELISTED);
        
        let last_update = table::borrow(&oracle.last_updates, collection_type);
        assert!(current_epoch - *last_update <= oracle.max_price_staleness_epochs, E_PRICE_TOO_STALE);
        
        *table::borrow(&oracle.floor_prices, collection_type)
    }
    
    /// Check if a collection is whitelisted and active
    public fun is_collection_whitelisted(oracle: &NFTCollectionOracle, collection_type: String): bool {
        let whitelist = df::borrow<CollectionWhitelistKey, Table<String, CollectionInfo>>(
            &oracle.id, 
            CollectionWhitelistKey {}
        );
        
        if (!table::contains(whitelist, collection_type)) {
            return false
        };
        
        let collection_info = table::borrow(whitelist, collection_type);
        collection_info.is_active
    }
    
    /// Automatically adjust quota based on current floor price (can be called by anyone)
    public entry fun auto_adjust_quota_for_price_change(
        oracle: &NFTCollectionOracle,
        cap: &mut PartnerCap,
        clock: &Clock,
        _ctx: &mut tx_context::TxContext
    ) {
        assert!(df::exists_(&cap.id, NFTCollateralKey {}), E_NFT_VALUATION_FAILED);
        
        let collateral_info = df::borrow_mut<NFTCollateralKey, NFTCollateralInfo>(&mut cap.id, NFTCollateralKey {});
        let collection_type = collateral_info.collection_type;
        
        // Get current floor price from oracle
        let current_floor_price = get_current_floor_price(oracle, collection_type, clock);
        let bundle_size = vector::length(&collateral_info.nft_ids);
        let current_total_value = current_floor_price * bundle_size;
        
        // Calculate price change percentage
        let old_value = collateral_info.estimated_floor_value_usdc;
        let price_change_bps = if (old_value > 0) {
            if (current_total_value > old_value) {
                ((current_total_value - old_value) * 10000) / old_value
            } else {
                ((old_value - current_total_value) * 10000) / old_value
            }
        } else {
            10000 // 100% change if starting from 0
        };
        
        // Only adjust if price change is significant
        if (price_change_bps >= PRICE_UPDATE_THRESHOLD_BPS) {
            // Update stored value
            collateral_info.estimated_floor_value_usdc = current_total_value;
            
            // Recalculate quota with collection-specific LTV
            let whitelist = df::borrow<CollectionWhitelistKey, Table<String, CollectionInfo>>(
                &oracle.id, 
                CollectionWhitelistKey {}
            );
            let collection_info = table::borrow(whitelist, collection_type);
            let effective_collateral_value = (current_total_value * collection_info.base_ltv) / 10000;
            let new_daily_quota = effective_collateral_value * POINTS_QUOTA_PER_USDC_COLLATERAL_UNIT;
            
            let old_quota = cap.daily_quota_pts;
            cap.daily_quota_pts = new_daily_quota;
            cap.collateral_value_usdc_at_creation = effective_collateral_value;
            
            // Adjust remaining quota proportionally
            if (old_quota > 0) {
                cap.mint_remaining_today = (cap.mint_remaining_today * new_daily_quota) / old_quota;
            } else {
                cap.mint_remaining_today = new_daily_quota;
            };
            
            let new_health_factor = calculate_health_factor(cap);
            
            event::emit(QuotaAutoAdjusted {
                partner_cap_id: object::uid_to_inner(&cap.id),
                collection_type,
                old_quota,
                new_quota: new_daily_quota,
                price_change_percent: price_change_bps,
                new_health_factor
            });
        }
    }
    
    /// Batch auto-adjust quotas for multiple PartnerCaps (efficient for mass updates)
    public fun batch_auto_adjust_quotas(
        oracle: &NFTCollectionOracle,
        caps: &mut vector<PartnerCap>,
        clock: &Clock,
        _ctx: &mut tx_context::TxContext
    ) {
        let mut i = 0;
        let len = vector::length(caps);
        
        while (i < len) {
            let cap = vector::borrow_mut(caps, i);
            
            if (df::exists_(&cap.id, NFTCollateralKey {})) {
                // Get collection type
                let collateral_info = df::borrow<NFTCollateralKey, NFTCollateralInfo>(&cap.id, NFTCollateralKey {});
                let collection_type = collateral_info.collection_type;
                
                // Check if price update is available and not stale
                if (table::contains(&oracle.floor_prices, collection_type)) {
                    let current_epoch = clock::timestamp_ms(clock) / (24 * 60 * 60 * 1000);
                    let last_update = table::borrow(&oracle.last_updates, collection_type);
                    
                    if (current_epoch - *last_update <= oracle.max_price_staleness_epochs) {
                        // Inline the adjustment logic for batch processing
                        let collateral_info_mut = df::borrow_mut<NFTCollateralKey, NFTCollateralInfo>(&mut cap.id, NFTCollateralKey {});
                        let current_floor_price = *table::borrow(&oracle.floor_prices, collection_type);
                        let bundle_size = vector::length(&collateral_info_mut.nft_ids);
                        let current_total_value = current_floor_price * bundle_size;
                        
                        let old_value = collateral_info_mut.estimated_floor_value_usdc;
                        if (old_value > 0) {
                            let price_change_bps = if (current_total_value > old_value) {
                                ((current_total_value - old_value) * 10000) / old_value
                            } else {
                                ((old_value - current_total_value) * 10000) / old_value
                            };
                            
                            if (price_change_bps >= PRICE_UPDATE_THRESHOLD_BPS) {
                                collateral_info_mut.estimated_floor_value_usdc = current_total_value;
                                
                                let whitelist = df::borrow<CollectionWhitelistKey, Table<String, CollectionInfo>>(
                                    &oracle.id, CollectionWhitelistKey {}
                                );
                                let collection_info = table::borrow(whitelist, collection_type);
                                let effective_collateral_value = (current_total_value * collection_info.base_ltv) / 10000;
                                let new_daily_quota = effective_collateral_value * POINTS_QUOTA_PER_USDC_COLLATERAL_UNIT;
                                
                                cap.daily_quota_pts = new_daily_quota;
                                cap.collateral_value_usdc_at_creation = effective_collateral_value;
                            }
                        }
                    }
                }
            };
            
            i = i + 1;
        }
    }

    // === TradePort Oracle Integration ===
    
    /// Oracle query result structure
    #[allow(unused_field)]
    public struct TradePortCollectionData has store {
        collection_id: String,
        floor_price_sui: u64, // Floor price in SUI (scaled by 1e9)
        floor_price_usdc: u64, // Floor price in USD cents
        volume_24h: u64,
        last_updated_epoch: u64
    }
    
    /// Fetch floor price from TradePort API (placeholder for off-chain oracle call)
    /// In production, this would be called by an authorized oracle service
    public fun update_collection_floor_price_from_oracle(
        oracle: &mut NFTCollectionOracle,
        _admin: &AdminCap,
        collection_type: String,
        _floor_price_sui: u64,
        floor_price_usdc: u64,
        _volume_24h: u64,
        current_epoch: u64,
        ctx: &mut tx_context::TxContext
    ) {
        assert!(table::contains(&oracle.floor_prices, collection_type), E_COLLECTION_NOT_WHITELISTED);
        
        let old_floor_price = if (table::contains(&oracle.floor_prices, collection_type)) {
            *table::borrow(&oracle.floor_prices, collection_type)
        } else {
            0
        };
        
        // Update the floor price data
        if (table::contains(&oracle.floor_prices, collection_type)) {
            *table::borrow_mut(&mut oracle.floor_prices, collection_type) = floor_price_usdc;
        } else {
            table::add(&mut oracle.floor_prices, collection_type, floor_price_usdc);
        };
        
        if (table::contains(&oracle.last_updates, collection_type)) {
            *table::borrow_mut(&mut oracle.last_updates, collection_type) = current_epoch;
        } else {
            table::add(&mut oracle.last_updates, collection_type, current_epoch);
        };
        
        // Calculate price change percentage (in basis points)
        let _price_change_bp = if (old_floor_price > 0) {
            let price_diff = if (floor_price_usdc > old_floor_price) {
                floor_price_usdc - old_floor_price
            } else {
                old_floor_price - floor_price_usdc
            };
            (price_diff * 10000) / old_floor_price
        } else {
            0
        };
        
        event::emit(NFTFloorPriceUpdated {
            collection_type,
            old_price_usdc: old_floor_price,
            new_price_usdc: floor_price_usdc,
            update_epoch: current_epoch,
            price_authority: tx_context::sender(ctx)
        });
    }
    
    /// TradePort GraphQL query structure for collection data
    /// This represents the expected structure from TradePort's API response
    /// GraphQL Query:
    /// ```
    /// query fetchCollectionFloor($collectionType: String!) {
    ///   sui {
    ///     collections(where: { collection_type: { _eq: $collectionType } }) {
    ///       id
    ///       title
    ///       floor
    ///       volume_24h
    ///       updated_at
    ///     }
    ///   }
    /// }
    /// ```
    public fun format_tradeport_api_call_info(): (String, String, String) {
        let api_endpoint = std::string::utf8(b"https://api.indexer.xyz/graphql");
        let query = std::string::utf8(b"query fetchCollectionFloor($collectionType: String!) { sui { collections(where: { collection_type: { _eq: $collectionType } }) { id title floor volume_24h updated_at } } }");
        let headers = std::string::utf8(b"x-api-key: YOUR_API_KEY, x-api-user: YOUR_API_USER");
        (api_endpoint, query, headers)
    }

    // === Automated SUI Collateral Management ===
    
    /// Auto-adjust SUI collateral quotas when SUI price changes significantly
    /// Integrated with external price oracle for real-time SUI/USD pricing
    public entry fun auto_adjust_sui_quotas_for_price_change(
        rate_oracle: &RateOracle,
        _external_oracle: &ExternalPriceOracle,
        partner_caps: vector<object::ID>, // Partner caps with SUI collateral to update
        _admin: &AdminCap,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        // Verify oracle is not stale
        oracle::assert_not_stale(rate_oracle, clock, ctx);
        
        let current_epoch = tx_context::epoch(ctx);
        let (current_rate, decimals) = oracle::get_rate(rate_oracle);
        
        let mut i = 0;
        let len = vector::length(&partner_caps);
        let updated_count = 0;
        
        while (i < len) {
            let _partner_cap_id = *vector::borrow(&partner_caps, i);
            
            // In a real implementation, you would:
            // 1. Fetch the partner cap object by ID
            // 2. Check if it has SUI collateral (non-zero collateral_value_usdc_at_creation and no NFT collateral)
            // 3. Calculate original SUI amount from stored USDC value
            // 4. Apply current price to get new USDC value
            // 5. Compare with stored value and adjust quota if price change exceeds threshold
            
            // Placeholder for the logic:
            // if (!has_nft_collateral(&partner_cap) && partner_cap.collateral_value_usdc_at_creation > 0) {
            //     let original_usdc_value = partner_cap.collateral_value_usdc_at_creation;
            //     let original_sui_amount = reverse_calculate_sui_from_usdc(original_usdc_value, stored_rate_at_creation);
            //     let current_usdc_value = oracle::price_in_usdc(rate_oracle, original_sui_amount);
            //     
            //     let price_change_bp = calculate_price_change_bp(original_usdc_value, current_usdc_value);
            //     if (price_change_bp >= SUI_PRICE_CHANGE_THRESHOLD_BP) {
            //         let new_quota = current_usdc_value * POINTS_QUOTA_PER_USDC_COLLATERAL_UNIT;
            //         update_partner_quota(&mut partner_cap, new_quota);
            //         updated_count = updated_count + 1;
            //     }
            // }
            
            i = i + 1;
        };
        
        // Emit batch update event
        event::emit(SUIQuotaBatchAdjustment {
            updated_partners: partner_caps,
            updated_count,
            trigger_epoch: current_epoch,
            current_sui_rate: current_rate,
            rate_decimals: decimals,
            updated_by: tx_context::sender(ctx)
        });
    }
    
    /// Revalue SUI collateral based on current oracle price
    /// This allows dynamic adjustment of partner quotas as SUI price changes
    public entry fun revalue_sui_collateral(
        _admin_cap: &AdminCap,
        cap: &mut PartnerCap,
        rate_oracle: &RateOracle,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        // Only revalue if this partner has SUI collateral (not NFT collateral)
        assert!(!has_nft_collateral(cap), E_NFT_VALUATION_FAILED);
        assert!(cap.collateral_value_usdc_at_creation > 0, E_COLLATERAL_VALUE_ZERO);
        
        // Verify oracle is fresh
        oracle::assert_not_stale(rate_oracle, clock, ctx);
        
        // Calculate original SUI amount from stored USDC value
        // This is a reverse calculation - we need to determine how much SUI was originally deposited
        // In practice, you'd want to store the original SUI amount separately for accuracy
        let stored_usdc_value = cap.collateral_value_usdc_at_creation;
        
        // For now, we'll estimate based on the assumption that the partner deposited SUI
        // and we'll recalculate its current value
        let (current_rate, _decimals) = oracle::get_rate(rate_oracle);
        
        // Calculate new USDC value based on current rate
        // Note: This is a simplified approach. In production, you'd want to store
        // the original SUI amount to avoid accumulating rounding errors
        let estimated_original_sui = stored_usdc_value * 1000000000; // Assume 1 USDC = 1B lamports roughly
        let new_usdc_value = oracle::price_in_usdc(rate_oracle, estimated_original_sui);
        
        // Update quota based on new valuation
        let old_quota = cap.daily_quota_pts;
        let new_quota = new_usdc_value * POINTS_QUOTA_PER_USDC_COLLATERAL_UNIT;
        
        cap.daily_quota_pts = new_quota;
        cap.collateral_value_usdc_at_creation = new_usdc_value;
        
        // Adjust remaining quota proportionally
        if (old_quota > 0) {
            cap.mint_remaining_today = (cap.mint_remaining_today * new_quota) / old_quota;
        } else {
            cap.mint_remaining_today = new_quota;
        };
        
        event::emit(SUICollateralRevalued {
            partner_cap_id: object::uid_to_inner(&cap.id),
            old_usdc_value: stored_usdc_value,
            new_usdc_value,
            old_quota,
            new_quota,
            current_rate,
            revalued_epoch: tx_context::epoch(ctx)
        });
    }
    
    /// Calculate health factor for SUI collateral based on current price
    /// Similar to NFT health factor but for SUI price volatility
    public fun calculate_sui_health_factor(
        cap: &PartnerCap,
        rate_oracle: &RateOracle,
        clock: &Clock,
        ctx: &tx_context::TxContext
    ): u64 {
        // Only for SUI collateral partners
        if (has_nft_collateral(cap) || cap.collateral_value_usdc_at_creation == 0) {
            return 10000 // Neutral health factor for non-SUI collateral
        };
        
        // Check if oracle is stale
        if (oracle::is_stale(rate_oracle, clock, ctx)) {
            return 5000 // Return poor health factor if oracle is stale
        };
        
        // Calculate current value of the original SUI collateral
        let stored_usdc_value = cap.collateral_value_usdc_at_creation;
        let estimated_original_sui = stored_usdc_value * 1000000000; // Simplified reverse calculation
        let current_usdc_value = oracle::price_in_usdc(rate_oracle, estimated_original_sui);
        
        // Health factor = (current_collateral_value / original_quota_basis) * 10000
        if (stored_usdc_value == 0) {
            return 10000
        };
        
        (current_usdc_value * 10000) / stored_usdc_value
    }
    
    /// Check if SUI collateral is at risk due to price changes
    public fun is_sui_collateral_at_risk(
        cap: &PartnerCap,
        rate_oracle: &RateOracle,
        clock: &Clock,
        ctx: &tx_context::TxContext
    ): bool {
        let health_factor = calculate_sui_health_factor(cap, rate_oracle, clock, ctx);
        health_factor < MIN_HEALTH_FACTOR
    }
    
    /// Batch health check for multiple SUI collateral partners
    public entry fun batch_sui_health_check(
        partner_caps: vector<object::ID>,
        rate_oracle: &RateOracle,
        _clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        let current_epoch = tx_context::epoch(ctx);
        let mut i = 0;
        let len = vector::length(&partner_caps);
        let at_risk_count = 0;
        
        while (i < len) {
            let _partner_cap_id = *vector::borrow(&partner_caps, i);
            
            // In a real implementation, you would:
            // 1. Fetch the partner cap object by ID
            // 2. Calculate health factor
            // 3. Emit warning events for at-risk partners
            // 4. Potentially take automatic protective actions
            
            // Placeholder for actual health check logic
            // if (is_sui_collateral_at_risk(&partner_cap, rate_oracle, clock, ctx)) {
            //     at_risk_count = at_risk_count + 1;
            //     event::emit(SUICollateralAtRisk {
            //         partner_cap_id,
            //         health_factor: calculate_sui_health_factor(&partner_cap, rate_oracle, clock, ctx),
            //         current_epoch
            //     });
            // }
            
            i = i + 1;
        };
        
        event::emit(SUIHealthCheckCompleted {
            total_checked: len,
            at_risk_count,
            check_epoch: current_epoch,
            oracle_rate: {
                let (rate, _decimals) = oracle::get_rate(rate_oracle);
                rate
            }
        });
    }

    // === SUI Collateral Events ===
    
    public struct SUICollateralRevalued has copy, drop {
        partner_cap_id: object::ID,
        old_usdc_value: u64,
        new_usdc_value: u64,
        old_quota: u64,
        new_quota: u64,
        current_rate: u128,
        revalued_epoch: u64
    }
    
    #[allow(unused_field)]
    public struct SUICollateralAtRisk has copy, drop {
        partner_cap_id: object::ID,
        health_factor: u64,
        current_epoch: u64
    }
    
    public struct SUIHealthCheckCompleted has copy, drop {
        total_checked: u64,
        at_risk_count: u64,
        check_epoch: u64,
        oracle_rate: u128
    }

    // === Enhanced Oracle Integration Constants ===
    #[allow(unused_const)]
    const SUI_PRICE_CHANGE_THRESHOLD_BP: u64 = 1000; // 10% SUI price change threshold
    #[allow(unused_const)]
    const SUI_COLLATERAL_LTV_RATIO: u64 = 10000; // 100% LTV for SUI (less volatile than NFTs)
    #[allow(unused_const)]
    const MIN_SUI_HEALTH_FACTOR: u64 = 8000; // 80% minimum health factor for SUI collateral

    /// Creates PartnerCap via USDC collateral deposit (permissionless)
    /// USDC provides stable 1:1 USDC value (no oracle needed)
    /// Uses 100% LTV since USDC is the base unit of account
    public entry fun create_partner_cap_with_usdc_collateral<USDCType>(
        usdc_collateral: Coin<USDCType>,
        partner_name: String,
        ctx: &mut tx_context::TxContext
    ) {
        let partner_address = tx_context::sender(ctx);
        let current_epoch = tx_context::epoch(ctx);
        let usdc_collateral_amount = coin::value(&usdc_collateral);
        
        // For USDC, the collateral value equals the coin amount (1:1)
        let collateral_value_usdc = usdc_collateral_amount;
        assert!(collateral_value_usdc > 0, E_COLLATERAL_VALUE_ZERO);
        
        // USDC uses 100% LTV since it's already in USDC terms (no conversion risk)
        let daily_quota = collateral_value_usdc * POINTS_QUOTA_PER_USDC_COLLATERAL_UNIT;
        
        let cap_id = object::new(ctx);
        
        // Create USDC collateral info
        let usdc_collateral_info = USDCCollateralInfo {
            usdc_amount_deposited: usdc_collateral_amount,
            deposit_timestamp: current_epoch,
            collateral_asset_type: type_name::get<USDCType>(),
        };
        
        let mut partner_cap = PartnerCap {
            id: cap_id,
            partner_name: partner_name,
            paused: false,
            daily_quota_pts: daily_quota,
            mint_remaining_today: daily_quota,
            collateral_value_usdc_at_creation: collateral_value_usdc,
            last_epoch: current_epoch,
        };
        
        // Store USDC collateral info as a dynamic field (upgrade-safe approach)
        df::add(&mut partner_cap.id, USDCCollateralKey {}, usdc_collateral_info);
        
        event::emit(PartnerCapCreatedWithUSDCCollateral {
            id: object::uid_to_inner(&partner_cap.id),
            partner_address,
            partner_name: partner_name,
            usdc_amount: usdc_collateral_amount,
            collateral_value_usdc,
            daily_quota_pts: daily_quota,
            usdc_coin_type: type_name::get<USDCType>()
        });
        
        // Store the USDC collateral in the contract (could be held in treasury or escrow)
        // For now, we'll transfer to a treasury address or burn
        // In production, you'd want to hold this in a proper treasury/escrow system
        transfer::public_transfer(usdc_collateral, @0x0); // Placeholder: send to zero address
        
        transfer::public_transfer(partner_cap, partner_address);
    }

    // === USDC Collateral Management Functions ===
    
    /// Returns whether the PartnerCap has USDC collateral
    public fun has_usdc_collateral(cap: &PartnerCap): bool {
        df::exists_(&cap.id, USDCCollateralKey {})
    }
    
    /// Returns the original USDC amount deposited (0 if no USDC collateral)
    public fun get_usdc_collateral_amount(cap: &PartnerCap): u64 {
        if (df::exists_(&cap.id, USDCCollateralKey {})) {
            let collateral_info = df::borrow<USDCCollateralKey, USDCCollateralInfo>(&cap.id, USDCCollateralKey {});
            collateral_info.usdc_amount_deposited
        } else {
            0
        }
    }
    
    /// Returns the USDC collateral deposit timestamp
    public fun get_usdc_deposit_timestamp(cap: &PartnerCap): u64 {
        if (df::exists_(&cap.id, USDCCollateralKey {})) {
            let collateral_info = df::borrow<USDCCollateralKey, USDCCollateralInfo>(&cap.id, USDCCollateralKey {});
            collateral_info.deposit_timestamp
        } else {
            0
        }
    }
    
    /// Returns the USDC coin type used for collateral
    public fun get_usdc_collateral_type(cap: &PartnerCap): TypeName {
        if (df::exists_(&cap.id, USDCCollateralKey {})) {
            let collateral_info = df::borrow<USDCCollateralKey, USDCCollateralInfo>(&cap.id, USDCCollateralKey {});
            collateral_info.collateral_asset_type
        } else {
            type_name::get<u8>() // Return dummy type if no USDC collateral
        }
    }
    
    /// Get collateral type for any PartnerCap (SUI, USDC, or NFT)
    public fun get_collateral_type(cap: &PartnerCap): String {
        if (has_nft_collateral(cap)) {
            std::string::utf8(b"NFT")
        } else if (has_usdc_collateral(cap)) {
            std::string::utf8(b"USDC")
        } else if (cap.collateral_value_usdc_at_creation > 0) {
            std::string::utf8(b"SUI")
        } else {
            std::string::utf8(b"NONE")
        }
    }
    
    /// Admin function to release USDC collateral (similar to NFT release)
    /// This allows partners to withdraw their USDC when quota usage is low
    public entry fun release_usdc_collateral<USDCType: drop>(
        cap: &mut PartnerCap,
        _admin: &AdminCap,
        ctx: &mut tx_context::TxContext
    ) {
        // Validate the USDC type matches the stored collateral type
        let stored_type = get_usdc_collateral_type(cap);
        let expected_type = type_name::get<USDCType>();
        assert!(stored_type == expected_type, E_NFT_VALUATION_FAILED);
        let caller = tx_context::sender(ctx);
        assert!(df::exists_(&cap.id, USDCCollateralKey {}), E_NFT_VALUATION_FAILED);
        
        // For USDC, we can be more lenient on health factor since there's no price volatility
        // But we still need to ensure responsible quota usage
        let health_factor = calculate_usdc_health_factor(cap);
        assert!(health_factor >= MIN_USDC_HEALTH_FACTOR, E_HEALTH_FACTOR_TOO_LOW);
        
        // Remove collateral info
        let collateral_info = df::remove<USDCCollateralKey, USDCCollateralInfo>(&mut cap.id, USDCCollateralKey {});
        let usdc_amount = collateral_info.usdc_amount_deposited;
        
        // Reset quota to zero since collateral is being removed
        cap.daily_quota_pts = 0;
        cap.mint_remaining_today = 0;
        cap.collateral_value_usdc_at_creation = 0;
        
        // Emit release event
        event::emit(USDCCollateralReleased {
            partner_cap_id: object::uid_to_inner(&cap.id),
            partner_address: caller,
            usdc_amount,
            release_timestamp: tx_context::epoch(ctx)
        });
        
        // TODO: Implement actual USDC transfer back to partner
        // In production, this would transfer USDC from treasury back to the partner
        // let usdc_to_return = coin::from_balance(balance::split(&mut treasury_balance, usdc_amount), ctx);
        // transfer::public_transfer(usdc_to_return, caller);
    }
    
    /// Calculate health factor for USDC collateral (simpler than SUI/NFT)
    /// Since USDC is stable, health factor is based on quota utilization
    public fun calculate_usdc_health_factor(cap: &PartnerCap): u64 {
        if (!has_usdc_collateral(cap) || cap.collateral_value_usdc_at_creation == 0) {
            return 10000 // Neutral health factor for non-USDC collateral
        };
        
        // For USDC, health factor is simply current quota vs original quota
        // Since USDC doesn't fluctuate in value like SUI
        let original_quota = cap.collateral_value_usdc_at_creation * POINTS_QUOTA_PER_USDC_COLLATERAL_UNIT;
        let quota_used = if (original_quota >= cap.mint_remaining_today) {
            original_quota - cap.mint_remaining_today
        } else {
            original_quota // Prevent underflow
        };
        
        if (quota_used == 0) {
            return 99999 // Max health factor if no quota used
        };
        
        // Health factor = (remaining_quota / original_quota) * 10000
        (cap.mint_remaining_today * 10000) / original_quota
    }
    
    /// Check if USDC collateral can be safely released
    public fun can_release_usdc_collateral(cap: &PartnerCap): bool {
        if (!has_usdc_collateral(cap)) {
            return false
        };
        calculate_usdc_health_factor(cap) >= MIN_USDC_HEALTH_FACTOR
    }

    // === Enhanced Collateral Constants ===
    const MIN_USDC_HEALTH_FACTOR: u64 = 5000; // 50% minimum health factor for USDC (more lenient than SUI/NFT)
    #[allow(unused_const)]
    const USDC_COLLATERAL_LTV_RATIO: u64 = 10000; // 100% LTV for USDC (no conversion risk)
}