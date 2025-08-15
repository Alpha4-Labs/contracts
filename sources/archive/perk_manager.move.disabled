/// Module for managing Perk Definitions and Claims by users.
module alpha_points::perk_manager {
    use std::string::{Self, String};
    use sui::dynamic_field;
    use sui::event;
    use sui::clock::{Self, Clock};

    use alpha_points::ledger;
    use alpha_points::partner_flex;
    use alpha_points::oracle;
    use alpha_points::admin;

    // === Error Constants ===
    const EInvalidRevenueSplitPercentage: u64 = 101;
    const EPerkNotActive: u64 = 102;
    const EMaxClaimsReached: u64 = 103;
    const ENotPerkCreator: u64 = 104;
    const EWrongPerkDefinition: u64 = 108;
    const EPerkNotConsumable: u64 = 109;
    const EMaxUsesReachedOnPerk: u64 = 110;
    const E_TOO_MANY_TAGS: u64 = 111;
    const E_PERK_TYPE_NOT_ALLOWED: u64 = 112;
    const E_PERK_TYPE_BLACKLISTED: u64 = 113;
    const E_COST_EXCEEDS_LIMIT: u64 = 114;
    const E_INVALID_REVENUE_SHARE: u64 = 115;
    const E_CONSUMABLE_PERKS_DISABLED: u64 = 116;
    const E_EXPIRING_PERKS_DISABLED: u64 = 117;
    const E_UNIQUE_METADATA_DISABLED: u64 = 118;
    const E_TAG_NOT_ALLOWED: u64 = 119;
    const E_TAG_BLACKLISTED: u64 = 120;
    const E_MAX_CLAIMS_EXCEEDS_LIMIT: u64 = 121;
    const E_MAX_PERKS_REACHED: u64 = 122;
    const ENotOwner: u64 = 123;
    const EWrongMetadata: u64 = 124;
    const ENoMetadata: u64 = 125;

    // === Structs ===

    /// Defines the revenue split policy for a perk.
    public struct RevenueSplitPolicy has store, copy, drop {
        partner_share_percentage: u8,
        platform_share_percentage: u8,
        partner_recipient_address: address,
        platform_recipient_address: address,
    }

    /// Defines a perk that partners can create and users can claim.
    public struct PerkDefinition has key, store {
        id: UID,
        name: String,
        description: String,
        creator_partner_cap_id: ID,
        perk_type: String,
        usdc_price: u64,
        current_alpha_points_price: u64,
        last_price_update_timestamp_ms: u64,
        revenue_split_policy: RevenueSplitPolicy,
        max_claims: Option<u64>,
        total_claims_count: u64,
        is_active: bool,
        definition_metadata_id: ID,
        generates_unique_claim_metadata: bool,
        max_uses_per_claim: Option<u64>,
        expiration_timestamp_ms: Option<u64>,
        tags: vector<String>,
        tag_metadata_id: ID,
    }

    /// Represents an instance of a perk claimed by a user.
    public struct ClaimedPerk has key, store {
        id: UID,
        perk_definition_id: ID,
        owner: address,
        claim_timestamp_ms: u64,
        status: String,
        claim_specific_metadata_id: Option<ID>,
        remaining_uses: Option<u64>,
    }

    public struct DefinitionMetadataStore has key, store {
        id: UID,
        marker: bool,
    }

    public struct ClaimSpecificMetadataStore has key, store {
        id: UID,
        marker: bool,
    }

    public struct TagMetadataStore has key, store {
        id: UID,
        marker: bool,
    }

    // === Events ===

    public struct PerkDefinitionCreated has copy, drop {
        perk_definition_id: ID,
        creator_partner_cap_id: ID,
        name: String,
        perk_type: String,
        cost_alpha_points: u64,
    }

    public struct PerkClaimed has copy, drop {
        claimed_perk_id: ID,
        perk_definition_id: ID,
        user_address: address,
        partner_cap_id: ID,
        cost_alpha_points: u64,
        partner_points_share: u64,
        platform_points_share: u64,
    }

    public struct ClaimedPerkStatusUpdated has copy, drop {
        claimed_perk_id: ID,
        perk_definition_id: ID,
        new_status: String,
    }

    public struct PerkDefinitionActivityUpdated has copy, drop {
        perk_definition_id: ID,
        is_active: bool,
    }

    public struct PerkDefinitionSettingsUpdated has copy, drop {
        perk_definition_id: ID,
        updated_by_partner_cap_id: ID,
        new_max_uses_per_claim: Option<u64>,
        new_expiration_timestamp_ms: Option<u64>,
    }

    public struct PerkTagsUpdated has copy, drop {
        perk_definition_id: ID,
        updated_by_partner_cap_id: ID,
        new_tags: vector<String>,
    }

    public struct PerkPriceUpdated has copy, drop {
        perk_definition_id: ID,
        usdc_price: u64,
        new_alpha_points_price: u64,
        timestamp_ms: u64,
    }

    public struct PerkClaimedWithTVLReinvestment has copy, drop {
        claimed_perk_id: ID,
        perk_definition_id: ID,
        user_address: address,
        partner_cap_id: ID,
        total_cost_alpha_points: u64,
        producer_direct_share: u64,
        tvl_reinvestment_share: u64,
        deployer_share: u64,
        tvl_increase_usdc: u64,
    }

    // === Public Functions ===

    public fun claim_metadata_exists(metadata_store: &ClaimSpecificMetadataStore, key: String): bool {
        dynamic_field::exists_<String>(&metadata_store.id, key)
    }

    public fun get_claim_metadata_id(claimed_perk: &ClaimedPerk): Option<ID> {
        claimed_perk.claim_specific_metadata_id
    }

    public fun get_claimed_perk_remaining_uses(claimed_perk: &ClaimedPerk): Option<u64> {
        claimed_perk.remaining_uses
    }

    public fun get_claimed_perk_status(claimed_perk: &ClaimedPerk): String {
        claimed_perk.status
    }

    public fun get_current_price(perk_definition: &PerkDefinition): (u64, u64) {
        (perk_definition.usdc_price, perk_definition.current_alpha_points_price)
    }

    public fun get_last_price_update(perk_definition: &PerkDefinition): u64 {
        perk_definition.last_price_update_timestamp_ms
    }

    public fun get_perk_definition_details(perk_definition: &PerkDefinition): (String, String, u64, bool, Option<u64>, Option<u64>) {
        (
            perk_definition.name,
            perk_definition.description,
            perk_definition.current_alpha_points_price,
            perk_definition.is_active,
            perk_definition.max_uses_per_claim,
            perk_definition.expiration_timestamp_ms
        )
    }

    public fun get_perk_tags(perk_definition: &PerkDefinition): &vector<String> {
        &perk_definition.tags
    }

    public fun has_claim_metadata(claimed_perk: &ClaimedPerk): bool {
        option::is_some(&claimed_perk.claim_specific_metadata_id)
    }

    public fun has_tag(perk_definition: &PerkDefinition, tag: &String): bool {
        let tags = &perk_definition.tags;
        let mut i = 0;
        while (i < vector::length(tags)) {
            if (string::as_bytes(vector::borrow(tags, i)) == string::as_bytes(tag)) {
                return true
            };
            i = i + 1;
        };
        false
    }

    public fun read_claim_metadata<T: copy + drop + store>(metadata_store: &ClaimSpecificMetadataStore, key: String): &T {
        dynamic_field::borrow<String, T>(&metadata_store.id, key)
    }

    // === Entry Functions ===

    /// @deprecated This function has hardcoded 70/20/10 revenue splits. 
    /// Use claim_perk_configurable_split() instead for configurable revenue splits that respect the frontend slider.
    public entry fun claim_perk(
        perk_definition: &mut PerkDefinition,
        partner_cap: &mut partner_flex::PartnerCapFlex,
        ledger: &mut ledger::Ledger,
        oracle: &oracle::RateOracle,
        clock_obj: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(perk_definition.is_active, EPerkNotActive);
        assert!(object::id(partner_cap) == perk_definition.creator_partner_cap_id, ENotPerkCreator);
        
        // Update price if needed
        if (clock::timestamp_ms(clock_obj) - perk_definition.last_price_update_timestamp_ms > 3600000) {
            update_perk_price(perk_definition, oracle, clock_obj, ctx);
        };

        // Check max claims
        if (option::is_some(&perk_definition.max_claims)) {
            assert!(perk_definition.total_claims_count < *option::borrow(&perk_definition.max_claims), EMaxClaimsReached);
        };

        let user_address = tx_context::sender(ctx);
        let cost = perk_definition.current_alpha_points_price;
        let epoch = tx_context::epoch(ctx);

        // Partner cap validations and minting
        partner_flex::reset_daily_mint_throttle(partner_cap, epoch);
        partner_flex::validate_mint_quota(partner_cap, cost * 70 / 100, epoch, ctx);

        // Spend user points
        ledger::internal_spend(ledger, user_address, cost, ctx);

        // Calculate splits (hardcoded 70/20/10)
        let producer_share = cost * 70 / 100;
        let tvl_reinvestment_share = cost * 20 / 100; 
        let deployer_share = cost - producer_share - tvl_reinvestment_share;

        let revenue_policy = &perk_definition.revenue_split_policy;
        
        // Distribute revenue
        ledger::internal_earn(ledger, revenue_policy.partner_recipient_address, producer_share, ctx);
        ledger::internal_earn(ledger, revenue_policy.platform_recipient_address, deployer_share, ctx);
        
        // Reinvest in TVL
        partner_flex::reinvest_perk_revenue_alpha_points(partner_cap, tvl_reinvestment_share, oracle, ctx);
        partner_flex::record_points_minted(partner_cap, producer_share, epoch, ctx);

        // Update claims count
        perk_definition.total_claims_count = perk_definition.total_claims_count + 1;

        // Handle metadata
        let mut claim_metadata_id = option::none<ID>();
        if (perk_definition.generates_unique_claim_metadata) {
            let metadata_store = ClaimSpecificMetadataStore {
                id: object::new(ctx),
                marker: true,
            };
            let metadata_id = object::id(&metadata_store);
            transfer::public_share_object(metadata_store);
            claim_metadata_id = option::some(metadata_id);
        };

        // Create claimed perk
        let claimed_perk = ClaimedPerk {
            id: object::new(ctx),
            perk_definition_id: object::id(perk_definition),
            owner: user_address,
            claim_timestamp_ms: clock::timestamp_ms(clock_obj),
            status: string::utf8(b"ACTIVE"),
            claim_specific_metadata_id: claim_metadata_id,
            remaining_uses: perk_definition.max_uses_per_claim,
        };

        // Emit events
        event::emit(PerkClaimedWithTVLReinvestment {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            total_cost_alpha_points: cost,
            producer_direct_share: producer_share,
            tvl_reinvestment_share,
            deployer_share,
            tvl_increase_usdc: oracle::price_in_usdc(oracle, tvl_reinvestment_share),
        });

        event::emit(PerkClaimed {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            cost_alpha_points: cost,
            partner_points_share: producer_share,
            platform_points_share: deployer_share,
        });

        // Transfer to user
        transfer::public_transfer(claimed_perk, user_address);
    }

    /// @deprecated This function has hardcoded 70/20/10 revenue splits.
    /// Use claim_perk_configurable_split() instead for configurable revenue splits that respect the frontend slider.
    public entry fun claim_perk_deployer_fixed(
        config: &admin::Config,
        perk_definition: &mut PerkDefinition,
        partner_cap: &mut partner_flex::PartnerCapFlex,
        ledger: &mut ledger::Ledger,
        oracle: &oracle::RateOracle,
        clock_obj: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(perk_definition.is_active, EPerkNotActive);
        assert!(object::id(partner_cap) == perk_definition.creator_partner_cap_id, ENotPerkCreator);
        
        // Update price if needed
        if (clock::timestamp_ms(clock_obj) - perk_definition.last_price_update_timestamp_ms > 3600000) {
            update_perk_price_fixed(perk_definition, clock_obj, ctx);
        };

        // Check max claims
        if (option::is_some(&perk_definition.max_claims)) {
            assert!(perk_definition.total_claims_count < *option::borrow(&perk_definition.max_claims), EMaxClaimsReached);
        };

        let user_address = tx_context::sender(ctx);
        let cost = perk_definition.current_alpha_points_price;
        let epoch = tx_context::epoch(ctx);

        // Partner cap validations and minting
        partner_flex::reset_daily_mint_throttle(partner_cap, epoch);
        partner_flex::validate_mint_quota(partner_cap, cost * 70 / 100, epoch, ctx);

        // Spend user points
        ledger::internal_spend(ledger, user_address, cost, ctx);

        // Calculate splits (hardcoded 70/20/10)
        let producer_share = cost * 70 / 100;
        let tvl_reinvestment_share = cost * 20 / 100; 
        let deployer_share = cost - producer_share - tvl_reinvestment_share;
        
        // Distribute revenue (using real deployer address)
        ledger::internal_earn(ledger, perk_definition.revenue_split_policy.partner_recipient_address, producer_share, ctx);
        ledger::internal_earn(ledger, admin::deployer_address(config), deployer_share, ctx);
        
        // Reinvest in TVL
        partner_flex::reinvest_perk_revenue_alpha_points(partner_cap, tvl_reinvestment_share, oracle, ctx);
        partner_flex::record_points_minted(partner_cap, producer_share, epoch, ctx);

        // Update claims count
        perk_definition.total_claims_count = perk_definition.total_claims_count + 1;

        // Handle metadata
        let mut claim_metadata_id = option::none<ID>();
        if (perk_definition.generates_unique_claim_metadata) {
            let metadata_store = ClaimSpecificMetadataStore {
                id: object::new(ctx),
                marker: true,
            };
            let metadata_id = object::id(&metadata_store);
            transfer::public_share_object(metadata_store);
            claim_metadata_id = option::some(metadata_id);
        };

        // Create claimed perk
        let claimed_perk = ClaimedPerk {
            id: object::new(ctx),
            perk_definition_id: object::id(perk_definition),
            owner: user_address,
            claim_timestamp_ms: clock::timestamp_ms(clock_obj),
            status: string::utf8(b"ACTIVE"),
            claim_specific_metadata_id: claim_metadata_id,
            remaining_uses: perk_definition.max_uses_per_claim,
        };

        // Emit events
        event::emit(PerkClaimedWithTVLReinvestment {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            total_cost_alpha_points: cost,
            producer_direct_share: producer_share,
            tvl_reinvestment_share,
            deployer_share,
            tvl_increase_usdc: oracle::price_in_usdc(oracle, tvl_reinvestment_share),
        });

        event::emit(PerkClaimed {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            cost_alpha_points: cost,
            partner_points_share: producer_share,
            platform_points_share: deployer_share,
        });

        // Transfer to user
        transfer::public_transfer(claimed_perk, user_address);
    }

    /// @deprecated This function has hardcoded 70/20/10 revenue splits.
    /// Use claim_perk_configurable_split() instead for configurable revenue splits that respect the frontend slider.
    public entry fun claim_perk_fixed(
        perk_definition: &mut PerkDefinition,
        partner_cap: &mut partner_flex::PartnerCapFlex,
        ledger: &mut ledger::Ledger,
        oracle: &oracle::RateOracle,
        clock_obj: &Clock,
        ctx: &mut TxContext
    ) {
        // Same as claim_perk but using update_perk_price_fixed
        assert!(perk_definition.is_active, EPerkNotActive);
        assert!(object::id(partner_cap) == perk_definition.creator_partner_cap_id, ENotPerkCreator);
        
        if (clock::timestamp_ms(clock_obj) - perk_definition.last_price_update_timestamp_ms > 3600000) {
            update_perk_price_fixed(perk_definition, clock_obj, ctx);
        };

        if (option::is_some(&perk_definition.max_claims)) {
            assert!(perk_definition.total_claims_count < *option::borrow(&perk_definition.max_claims), EMaxClaimsReached);
        };

        let user_address = tx_context::sender(ctx);
        let cost = perk_definition.current_alpha_points_price;
        let epoch = tx_context::epoch(ctx);

        partner_flex::reset_daily_mint_throttle(partner_cap, epoch);
        partner_flex::validate_mint_quota(partner_cap, cost * 70 / 100, epoch, ctx);
        ledger::internal_spend(ledger, user_address, cost, ctx);

        let producer_share = cost * 70 / 100;
        let tvl_reinvestment_share = cost * 20 / 100; 
        let deployer_share = cost - producer_share - tvl_reinvestment_share;

        let revenue_policy = &perk_definition.revenue_split_policy;
        ledger::internal_earn(ledger, revenue_policy.partner_recipient_address, producer_share, ctx);
        ledger::internal_earn(ledger, revenue_policy.platform_recipient_address, deployer_share, ctx);
        partner_flex::reinvest_perk_revenue_alpha_points(partner_cap, tvl_reinvestment_share, oracle, ctx);
        partner_flex::record_points_minted(partner_cap, producer_share, epoch, ctx);

        perk_definition.total_claims_count = perk_definition.total_claims_count + 1;

        let mut claim_metadata_id = option::none<ID>();
        if (perk_definition.generates_unique_claim_metadata) {
            let metadata_store = ClaimSpecificMetadataStore {
                id: object::new(ctx),
                marker: true,
            };
            let metadata_id = object::id(&metadata_store);
            transfer::public_share_object(metadata_store);
            claim_metadata_id = option::some(metadata_id);
        };

        let claimed_perk = ClaimedPerk {
            id: object::new(ctx),
            perk_definition_id: object::id(perk_definition),
            owner: user_address,
            claim_timestamp_ms: clock::timestamp_ms(clock_obj),
            status: string::utf8(b"ACTIVE"),
            claim_specific_metadata_id: claim_metadata_id,
            remaining_uses: perk_definition.max_uses_per_claim,
        };

        event::emit(PerkClaimedWithTVLReinvestment {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            total_cost_alpha_points: cost,
            producer_direct_share: producer_share,
            tvl_reinvestment_share,
            deployer_share,
            tvl_increase_usdc: oracle::price_in_usdc(oracle, tvl_reinvestment_share),
        });

        event::emit(PerkClaimed {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            cost_alpha_points: cost,
            partner_points_share: producer_share,
            platform_points_share: deployer_share,
        });

        transfer::public_transfer(claimed_perk, user_address);
    }

    /// @deprecated This function has hardcoded 70/20/10 revenue splits.
    /// Use claim_perk_with_metadata_configurable_split() instead for configurable revenue splits that respect the frontend slider.
    public entry fun claim_perk_with_metadata(
        perk_definition: &mut PerkDefinition,
        partner_cap: &mut partner_flex::PartnerCapFlex,
        ledger: &mut ledger::Ledger,
        oracle: &oracle::RateOracle,
        metadata_key: String,
        metadata_value: String,
        clock_obj: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(perk_definition.is_active, EPerkNotActive);
        assert!(object::id(partner_cap) == perk_definition.creator_partner_cap_id, ENotPerkCreator);
        
        if (clock::timestamp_ms(clock_obj) - perk_definition.last_price_update_timestamp_ms > 3600000) {
            update_perk_price(perk_definition, oracle, clock_obj, ctx);
        };

        if (option::is_some(&perk_definition.max_claims)) {
            assert!(perk_definition.total_claims_count < *option::borrow(&perk_definition.max_claims), EMaxClaimsReached);
        };

        let user_address = tx_context::sender(ctx);
        let cost = perk_definition.current_alpha_points_price;
        let epoch = tx_context::epoch(ctx);

        partner_flex::reset_daily_mint_throttle(partner_cap, epoch);
        partner_flex::validate_mint_quota(partner_cap, cost * 70 / 100, epoch, ctx);
        ledger::internal_spend(ledger, user_address, cost, ctx);

        let producer_share = cost * 70 / 100;
        let tvl_reinvestment_share = cost * 20 / 100; 
        let deployer_share = cost - producer_share - tvl_reinvestment_share;

        let revenue_policy = &perk_definition.revenue_split_policy;
        ledger::internal_earn(ledger, revenue_policy.partner_recipient_address, producer_share, ctx);
        ledger::internal_earn(ledger, revenue_policy.platform_recipient_address, deployer_share, ctx);
        partner_flex::reinvest_perk_revenue_alpha_points(partner_cap, tvl_reinvestment_share, oracle, ctx);
        partner_flex::record_points_minted(partner_cap, producer_share, epoch, ctx);

        perk_definition.total_claims_count = perk_definition.total_claims_count + 1;

        let mut metadata_store = ClaimSpecificMetadataStore {
            id: object::new(ctx),
            marker: true,
        };
        dynamic_field::add<String, String>(&mut metadata_store.id, metadata_key, metadata_value);
        let metadata_id = object::id(&metadata_store);
        transfer::public_share_object(metadata_store);

        let claimed_perk = ClaimedPerk {
            id: object::new(ctx),
            perk_definition_id: object::id(perk_definition),
            owner: user_address,
            claim_timestamp_ms: clock::timestamp_ms(clock_obj),
            status: string::utf8(b"ACTIVE"),
            claim_specific_metadata_id: option::some(metadata_id),
            remaining_uses: perk_definition.max_uses_per_claim,
        };

        event::emit(PerkClaimedWithTVLReinvestment {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            total_cost_alpha_points: cost,
            producer_direct_share: producer_share,
            tvl_reinvestment_share,
            deployer_share,
            tvl_increase_usdc: oracle::price_in_usdc(oracle, tvl_reinvestment_share),
        });

        event::emit(PerkClaimed {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            cost_alpha_points: cost,
            partner_points_share: producer_share,
            platform_points_share: deployer_share,
        });

        transfer::public_transfer(claimed_perk, user_address);
    }

    /// @deprecated This function has hardcoded 70/20/10 revenue splits.
    /// Use claim_perk_with_metadata_configurable_split() instead for configurable revenue splits that respect the frontend slider.
    public entry fun claim_perk_with_metadata_deployer_fixed(
        config: &admin::Config,
        perk_definition: &mut PerkDefinition,
        partner_cap: &mut partner_flex::PartnerCapFlex,
        ledger: &mut ledger::Ledger,
        oracle: &oracle::RateOracle,
        metadata_key: String,
        metadata_value: String,
        clock_obj: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(perk_definition.is_active, EPerkNotActive);
        assert!(object::id(partner_cap) == perk_definition.creator_partner_cap_id, ENotPerkCreator);
        
        if (clock::timestamp_ms(clock_obj) - perk_definition.last_price_update_timestamp_ms > 3600000) {
            update_perk_price_fixed(perk_definition, clock_obj, ctx);
        };

        if (option::is_some(&perk_definition.max_claims)) {
            assert!(perk_definition.total_claims_count < *option::borrow(&perk_definition.max_claims), EMaxClaimsReached);
        };

        let user_address = tx_context::sender(ctx);
        let cost = perk_definition.current_alpha_points_price;
        let epoch = tx_context::epoch(ctx);

        partner_flex::reset_daily_mint_throttle(partner_cap, epoch);
        partner_flex::validate_mint_quota(partner_cap, cost * 70 / 100, epoch, ctx);
        ledger::internal_spend(ledger, user_address, cost, ctx);

        let producer_share = cost * 70 / 100;
        let tvl_reinvestment_share = cost * 20 / 100; 
        let deployer_share = cost - producer_share - tvl_reinvestment_share;

        ledger::internal_earn(ledger, perk_definition.revenue_split_policy.partner_recipient_address, producer_share, ctx);
        ledger::internal_earn(ledger, admin::deployer_address(config), deployer_share, ctx);
        partner_flex::reinvest_perk_revenue_alpha_points(partner_cap, tvl_reinvestment_share, oracle, ctx);
        partner_flex::record_points_minted(partner_cap, producer_share, epoch, ctx);

        perk_definition.total_claims_count = perk_definition.total_claims_count + 1;

        let mut metadata_store = ClaimSpecificMetadataStore {
            id: object::new(ctx),
            marker: true,
        };
        dynamic_field::add<String, String>(&mut metadata_store.id, metadata_key, metadata_value);
        let metadata_id = object::id(&metadata_store);
        transfer::public_share_object(metadata_store);

        let claimed_perk = ClaimedPerk {
            id: object::new(ctx),
            perk_definition_id: object::id(perk_definition),
            owner: user_address,
            claim_timestamp_ms: clock::timestamp_ms(clock_obj),
            status: string::utf8(b"ACTIVE"),
            claim_specific_metadata_id: option::some(metadata_id),
            remaining_uses: perk_definition.max_uses_per_claim,
        };

        event::emit(PerkClaimedWithTVLReinvestment {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            total_cost_alpha_points: cost,
            producer_direct_share: producer_share,
            tvl_reinvestment_share,
            deployer_share,
            tvl_increase_usdc: oracle::price_in_usdc(oracle, tvl_reinvestment_share),
        });

        event::emit(PerkClaimed {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            cost_alpha_points: cost,
            partner_points_share: producer_share,
            platform_points_share: deployer_share,
        });

        transfer::public_transfer(claimed_perk, user_address);
    }

    /// @deprecated This function has hardcoded 70/20/10 revenue splits.
    /// Use claim_perk_with_metadata_configurable_split() instead for configurable revenue splits that respect the frontend slider.
    public entry fun claim_perk_with_metadata_fixed(
        perk_definition: &mut PerkDefinition,
        partner_cap: &mut partner_flex::PartnerCapFlex,
        ledger: &mut ledger::Ledger,
        oracle: &oracle::RateOracle,
        metadata_key: String,
        metadata_value: String,
        clock_obj: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(perk_definition.is_active, EPerkNotActive);
        assert!(object::id(partner_cap) == perk_definition.creator_partner_cap_id, ENotPerkCreator);
        
        if (clock::timestamp_ms(clock_obj) - perk_definition.last_price_update_timestamp_ms > 3600000) {
            update_perk_price_fixed(perk_definition, clock_obj, ctx);
        };

        if (option::is_some(&perk_definition.max_claims)) {
            assert!(perk_definition.total_claims_count < *option::borrow(&perk_definition.max_claims), EMaxClaimsReached);
        };

        let user_address = tx_context::sender(ctx);
        let cost = perk_definition.current_alpha_points_price;
        let epoch = tx_context::epoch(ctx);

        partner_flex::reset_daily_mint_throttle(partner_cap, epoch);
        partner_flex::validate_mint_quota(partner_cap, cost * 70 / 100, epoch, ctx);
        ledger::internal_spend(ledger, user_address, cost, ctx);

        let producer_share = cost * 70 / 100;
        let tvl_reinvestment_share = cost * 20 / 100; 
        let deployer_share = cost - producer_share - tvl_reinvestment_share;

        let revenue_policy = &perk_definition.revenue_split_policy;
        ledger::internal_earn(ledger, revenue_policy.partner_recipient_address, producer_share, ctx);
        ledger::internal_earn(ledger, revenue_policy.platform_recipient_address, deployer_share, ctx);
        partner_flex::reinvest_perk_revenue_alpha_points(partner_cap, tvl_reinvestment_share, oracle, ctx);
        partner_flex::record_points_minted(partner_cap, producer_share, epoch, ctx);

        perk_definition.total_claims_count = perk_definition.total_claims_count + 1;

        let mut metadata_store = ClaimSpecificMetadataStore {
            id: object::new(ctx),
            marker: true,
        };
        dynamic_field::add<String, String>(&mut metadata_store.id, metadata_key, metadata_value);
        let metadata_id = object::id(&metadata_store);
        transfer::public_share_object(metadata_store);

        let claimed_perk = ClaimedPerk {
            id: object::new(ctx),
            perk_definition_id: object::id(perk_definition),
            owner: user_address,
            claim_timestamp_ms: clock::timestamp_ms(clock_obj),
            status: string::utf8(b"ACTIVE"),
            claim_specific_metadata_id: option::some(metadata_id),
            remaining_uses: perk_definition.max_uses_per_claim,
        };

        event::emit(PerkClaimedWithTVLReinvestment {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            total_cost_alpha_points: cost,
            producer_direct_share: producer_share,
            tvl_reinvestment_share,
            deployer_share,
            tvl_increase_usdc: oracle::price_in_usdc(oracle, tvl_reinvestment_share),
        });

        event::emit(PerkClaimed {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            cost_alpha_points: cost,
            partner_points_share: producer_share,
            platform_points_share: deployer_share,
        });

        transfer::public_transfer(claimed_perk, user_address);
    }

    public entry fun create_perk_definition_deployer_fixed(
        config: &admin::Config,
        partner_cap: &mut partner_flex::PartnerCapFlex,
        name: String,
        description: String,
        perk_type: String,
        usdc_price: u64,
        partner_share_percentage: u8,
        max_uses_per_claim: Option<u64>,
        expiration_timestamp_ms: Option<u64>,
        generates_unique_claim_metadata: bool,
        tags: vector<String>,
        max_claims: Option<u64>,
        definition_metadata_keys: vector<String>,
        definition_metadata_values: vector<String>,
        is_active: bool,
        clock_obj: &Clock,
        ctx: &mut TxContext
    ) {
        let control_settings = partner_flex::get_perk_control_settings(partner_cap);
        let alpha_points_price = usdc_price * 1000;

        // Validation checks
        assert!(
            vector::is_empty(partner_flex::get_allowed_perk_types(control_settings)) || 
            vector::contains(partner_flex::get_allowed_perk_types(control_settings), &perk_type), 
            E_PERK_TYPE_NOT_ALLOWED
        );
        assert!(!vector::contains(partner_flex::get_blacklisted_perk_types(control_settings), &perk_type), E_PERK_TYPE_BLACKLISTED);
        assert!(alpha_points_price <= partner_flex::get_max_cost_per_perk(control_settings), E_COST_EXCEEDS_LIMIT);
        assert!(
            partner_share_percentage >= partner_flex::get_min_partner_share_percentage(control_settings) &&
            partner_share_percentage <= partner_flex::get_max_partner_share_percentage(control_settings),
            E_INVALID_REVENUE_SHARE
        );

        if (option::is_some(&max_uses_per_claim)) {
            assert!(partner_flex::get_allow_consumable_perks(control_settings), E_CONSUMABLE_PERKS_DISABLED);
        };
        if (option::is_some(&expiration_timestamp_ms)) {
            assert!(partner_flex::get_allow_expiring_perks(control_settings), E_EXPIRING_PERKS_DISABLED);
        };
        if (generates_unique_claim_metadata) {
            assert!(partner_flex::get_allow_unique_metadata(control_settings), E_UNIQUE_METADATA_DISABLED);
        };

        let mut i = 0;
        while (i < vector::length(&tags)) {
            let tag = vector::borrow(&tags, i);
            assert!(
                vector::is_empty(partner_flex::get_allowed_tags(control_settings)) || 
                vector::contains(partner_flex::get_allowed_tags(control_settings), tag), 
                E_TAG_NOT_ALLOWED
            );
            assert!(!vector::contains(partner_flex::get_blacklisted_tags(control_settings), tag), E_TAG_BLACKLISTED);
            i = i + 1;
        };

        if (option::is_some(&max_claims)) {
            assert!(*option::borrow(&max_claims) <= partner_flex::get_max_claims_per_perk(control_settings), E_MAX_CLAIMS_EXCEEDS_LIMIT);
        };

        assert!(partner_flex::get_total_perks_created(partner_cap) < partner_flex::get_max_perks_per_partner(control_settings), E_MAX_PERKS_REACHED);
        assert!(partner_share_percentage <= 100, EInvalidRevenueSplitPercentage);

        let revenue_split = RevenueSplitPolicy {
            partner_share_percentage,
            platform_share_percentage: 100 - partner_share_percentage,
            partner_recipient_address: tx_context::sender(ctx),
            platform_recipient_address: admin::deployer_address(config),
        };

        let mut def_metadata = DefinitionMetadataStore {
            id: object::new(ctx),
            marker: true,
        };

        let mut j = 0;
        assert!(vector::length(&definition_metadata_keys) == vector::length(&definition_metadata_values), 0);
        while (j < vector::length(&definition_metadata_keys)) {
            dynamic_field::add<String, String>(&mut def_metadata.id, *vector::borrow(&definition_metadata_keys, j), *vector::borrow(&definition_metadata_values, j));
            j = j + 1;
        };
        
        let tag_metadata = TagMetadataStore {
            id: object::new(ctx),
            marker: true,
        };
        
        // Store IDs before moving objects
        let def_metadata_id = object::id(&def_metadata);
        let tag_metadata_id = object::id(&tag_metadata);
        
        transfer::public_share_object(def_metadata);
        transfer::public_share_object(tag_metadata);

        let id = object::new(ctx);
        let perk_definition_id = object::uid_to_inner(&id);
        let perk_definition = PerkDefinition {
            id,
            name,
            description,
            creator_partner_cap_id: object::id(partner_cap),
            perk_type,
            usdc_price,
            current_alpha_points_price: alpha_points_price,
            last_price_update_timestamp_ms: clock::timestamp_ms(clock_obj),
            revenue_split_policy: revenue_split,
            max_claims,
            total_claims_count: 0,
            is_active,
            definition_metadata_id: def_metadata_id,
            generates_unique_claim_metadata,
            max_uses_per_claim,
            expiration_timestamp_ms,
            tags,
            tag_metadata_id: tag_metadata_id,
        };

        event::emit(PerkDefinitionCreated {
            perk_definition_id: perk_definition_id,
            creator_partner_cap_id: object::id(partner_cap),
            name: perk_definition.name,
            perk_type: perk_definition.perk_type,
            cost_alpha_points: alpha_points_price,
        });
        
        partner_flex::record_perk_created(partner_cap, ctx);
        transfer::share_object(perk_definition);
    }

    public entry fun create_perk_definition_fixed(
        partner_cap: &mut partner_flex::PartnerCapFlex,
        name: String,
        description: String,
        perk_type: String,
        usdc_price: u64,
        partner_share_percentage: u8,
        max_uses_per_claim: Option<u64>,
        expiration_timestamp_ms: Option<u64>,
        generates_unique_claim_metadata: bool,
        tags: vector<String>,
        max_claims: Option<u64>,
        definition_metadata_keys: vector<String>,
        definition_metadata_values: vector<String>,
        is_active: bool,
        clock_obj: &Clock,
        ctx: &mut TxContext
    ) {
        let control_settings = partner_flex::get_perk_control_settings(partner_cap);
        let alpha_points_price = usdc_price * 1000;

        // Validation checks (same as create_perk_definition)
        assert!(
            vector::is_empty(partner_flex::get_allowed_perk_types(control_settings)) || 
            vector::contains(partner_flex::get_allowed_perk_types(control_settings), &perk_type), 
            E_PERK_TYPE_NOT_ALLOWED
        );
        assert!(!vector::contains(partner_flex::get_blacklisted_perk_types(control_settings), &perk_type), E_PERK_TYPE_BLACKLISTED);
        assert!(alpha_points_price <= partner_flex::get_max_cost_per_perk(control_settings), E_COST_EXCEEDS_LIMIT);
        assert!(
            partner_share_percentage >= partner_flex::get_min_partner_share_percentage(control_settings) && 
            partner_share_percentage <= partner_flex::get_max_partner_share_percentage(control_settings), 
            E_INVALID_REVENUE_SHARE
        );
        
        if (option::is_some(&max_uses_per_claim)) {
            assert!(partner_flex::get_allow_consumable_perks(control_settings), E_CONSUMABLE_PERKS_DISABLED);
        };
        if (option::is_some(&expiration_timestamp_ms)) {
            assert!(partner_flex::get_allow_expiring_perks(control_settings), E_EXPIRING_PERKS_DISABLED);
        };
        if (generates_unique_claim_metadata) {
            assert!(partner_flex::get_allow_unique_metadata(control_settings), E_UNIQUE_METADATA_DISABLED);
        };

        let mut i = 0;
        while (i < vector::length(&tags)) {
            let tag = vector::borrow(&tags, i);
            assert!(
                vector::is_empty(partner_flex::get_allowed_tags(control_settings)) || 
                vector::contains(partner_flex::get_allowed_tags(control_settings), tag), 
                E_TAG_NOT_ALLOWED
            );
            assert!(!vector::contains(partner_flex::get_blacklisted_tags(control_settings), tag), E_TAG_BLACKLISTED);
            i = i + 1;
        };

        if (option::is_some(&max_claims)) {
            assert!(*option::borrow(&max_claims) <= partner_flex::get_max_claims_per_perk(control_settings), E_MAX_CLAIMS_EXCEEDS_LIMIT);
        };

        assert!(partner_flex::get_total_perks_created(partner_cap) < partner_flex::get_max_perks_per_partner(control_settings), E_MAX_PERKS_REACHED);
        assert!(partner_share_percentage <= 100, EInvalidRevenueSplitPercentage);

        let revenue_split = RevenueSplitPolicy {
            partner_share_percentage,
            platform_share_percentage: 100 - partner_share_percentage,
            partner_recipient_address: tx_context::sender(ctx),
            platform_recipient_address: @0xdeadbeef,
        };

        let mut def_metadata = DefinitionMetadataStore {
            id: object::new(ctx),
            marker: true,
        };

        let mut j = 0;
        assert!(vector::length(&definition_metadata_keys) == vector::length(&definition_metadata_values), 0);
        while (j < vector::length(&definition_metadata_keys)) {
            dynamic_field::add<String, String>(&mut def_metadata.id, *vector::borrow(&definition_metadata_keys, j), *vector::borrow(&definition_metadata_values, j));
            j = j + 1;
        };
        
        let tag_metadata = TagMetadataStore {
            id: object::new(ctx),
            marker: true,
        };
        
        // Store IDs before moving objects
        let def_metadata_id = object::id(&def_metadata);
        let tag_metadata_id = object::id(&tag_metadata);
        
        transfer::public_share_object(def_metadata);
        transfer::public_share_object(tag_metadata);

        let id = object::new(ctx);
        let perk_definition_id = object::uid_to_inner(&id);
        let perk_definition = PerkDefinition {
            id,
            name,
            description,
            creator_partner_cap_id: object::id(partner_cap),
            perk_type,
            usdc_price,
            current_alpha_points_price: alpha_points_price,
            last_price_update_timestamp_ms: clock::timestamp_ms(clock_obj),
            revenue_split_policy: revenue_split,
            max_claims,
            total_claims_count: 0,
            is_active,
            definition_metadata_id: def_metadata_id,
            generates_unique_claim_metadata,
            max_uses_per_claim,
            expiration_timestamp_ms,
            tags,
            tag_metadata_id: tag_metadata_id,
        };

        event::emit(PerkDefinitionCreated {
            perk_definition_id: perk_definition_id,
            creator_partner_cap_id: object::id(partner_cap),
            name: perk_definition.name,
            perk_type: perk_definition.perk_type,
            cost_alpha_points: alpha_points_price,
        });

        partner_flex::record_perk_created(partner_cap, ctx);
        transfer::share_object(perk_definition);
    }

    public entry fun update_claimed_perk_status(
        partner_cap: &partner_flex::PartnerCapFlex,
        claimed_perk: &mut ClaimedPerk,
        perk_definition: &PerkDefinition,
        new_status: String,
        _ctx: &mut TxContext
    ) {
        assert!(object::id(perk_definition) == claimed_perk.perk_definition_id, EWrongPerkDefinition);
        assert!(object::id(partner_cap) == perk_definition.creator_partner_cap_id, ENotPerkCreator);
        
        claimed_perk.status = new_status;
        
        event::emit(ClaimedPerkStatusUpdated {
            claimed_perk_id: object::id(claimed_perk),
            perk_definition_id: claimed_perk.perk_definition_id,
            new_status: claimed_perk.status,
        });
    }

    public entry fun update_perk_definition_settings(
        partner_cap: &partner_flex::PartnerCapFlex,
        perk_definition: &mut PerkDefinition,
        new_max_uses_per_claim: Option<u64>,
        new_expiration_timestamp_ms: Option<u64>,
        _ctx: &mut TxContext
    ) {
        assert!(object::id(partner_cap) == perk_definition.creator_partner_cap_id, ENotPerkCreator);
        
        perk_definition.max_uses_per_claim = new_max_uses_per_claim;
        perk_definition.expiration_timestamp_ms = new_expiration_timestamp_ms;
        
        event::emit(PerkDefinitionSettingsUpdated {
            perk_definition_id: object::id(perk_definition),
            updated_by_partner_cap_id: object::id(partner_cap),
            new_max_uses_per_claim: perk_definition.max_uses_per_claim,
            new_expiration_timestamp_ms: perk_definition.expiration_timestamp_ms,
        });
    }

    public entry fun update_perk_tags(
        partner_cap: &partner_flex::PartnerCapFlex,
        perk_definition: &mut PerkDefinition,
        new_tags: vector<String>,
        _ctx: &mut TxContext
    ) {
        assert!(object::id(partner_cap) == perk_definition.creator_partner_cap_id, ENotPerkCreator);
        assert!(vector::length(&new_tags) <= 5, E_TOO_MANY_TAGS);
        
        perk_definition.tags = new_tags;
        
        event::emit(PerkTagsUpdated {
            perk_definition_id: object::id(perk_definition),
            updated_by_partner_cap_id: object::id(partner_cap),
            new_tags: perk_definition.tags,
        });
    }

    public entry fun update_perk_price(
        perk_definition: &mut PerkDefinition,
        rate_oracle: &oracle::RateOracle,
        clock_obj: &Clock,
        _ctx: &mut TxContext
    ) {
        let timestamp = clock::timestamp_ms(clock_obj);
        let (rate, decimals) = oracle::get_rate(rate_oracle);
        let new_price = oracle::convert_asset_to_points(perk_definition.usdc_price, rate, decimals);
        perk_definition.current_alpha_points_price = new_price;
        perk_definition.last_price_update_timestamp_ms = timestamp;

        event::emit(PerkPriceUpdated {
            perk_definition_id: object::id(perk_definition),
            usdc_price: perk_definition.usdc_price,
            new_alpha_points_price: new_price,
            timestamp_ms: timestamp,
        });
    }

    public entry fun update_perk_price_fixed(
        perk_definition: &mut PerkDefinition,
        clock_obj: &Clock,
        _ctx: &mut TxContext
    ) {
        let timestamp = clock::timestamp_ms(clock_obj);
        let new_price = perk_definition.usdc_price * 1000;
        perk_definition.current_alpha_points_price = new_price;
        perk_definition.last_price_update_timestamp_ms = timestamp;

        event::emit(PerkPriceUpdated {
            perk_definition_id: object::id(perk_definition),
            usdc_price: perk_definition.usdc_price,
            new_alpha_points_price: new_price,
            timestamp_ms: timestamp,
        });
    }

    // Add other essential functions from the bytecode...
    public entry fun consume_perk_use(
        claimed_perk: &mut ClaimedPerk,
        perk_definition: &PerkDefinition,
        _ctx: &mut TxContext
    ) {
        assert!(object::id(perk_definition) == claimed_perk.perk_definition_id, EWrongPerkDefinition);
        assert!(option::is_some(&claimed_perk.remaining_uses), EPerkNotConsumable);
        
        let remaining = option::borrow_mut(&mut claimed_perk.remaining_uses);
        assert!(*remaining > 0, EMaxUsesReachedOnPerk);
        *remaining = *remaining - 1;
        
        if (*remaining == 0) {
            claimed_perk.status = string::utf8(b"FULLY_CONSUMED");
        };
    }

    public entry fun set_perk_definition_active_status(
        partner_cap: &partner_flex::PartnerCapFlex,
        perk_definition: &mut PerkDefinition,
        is_active: bool,
        _ctx: &mut TxContext
    ) {
        assert!(object::id(partner_cap) == perk_definition.creator_partner_cap_id, ENotPerkCreator);
        perk_definition.is_active = is_active;
        
        event::emit(PerkDefinitionActivityUpdated {
            perk_definition_id: object::id(perk_definition),
            is_active: perk_definition.is_active,
        });
    }

    public entry fun create_perk_definition(
        partner_cap: &mut partner_flex::PartnerCapFlex,
        rate_oracle: &oracle::RateOracle,
        name: String,
        description: String,
        perk_type: String,
        usdc_price: u64,
        partner_share_percentage: u8,
        max_uses_per_claim: Option<u64>,
        expiration_timestamp_ms: Option<u64>,
        generates_unique_claim_metadata: bool,
        tags: vector<String>,
        max_claims: Option<u64>,
        definition_metadata_keys: vector<String>,
        definition_metadata_values: vector<String>,
        is_active: bool,
        clock_obj: &Clock,
        ctx: &mut TxContext
    ) {
        let control_settings = partner_flex::get_perk_control_settings(partner_cap);
        let (rate, decimals) = oracle::get_rate(rate_oracle);
        let alpha_points_price = oracle::convert_asset_to_points(usdc_price, rate, decimals);

        // Validation checks
        assert!(
            vector::is_empty(partner_flex::get_allowed_perk_types(control_settings)) || 
            vector::contains(partner_flex::get_allowed_perk_types(control_settings), &perk_type), 
            E_PERK_TYPE_NOT_ALLOWED
        );
        assert!(!vector::contains(partner_flex::get_blacklisted_perk_types(control_settings), &perk_type), E_PERK_TYPE_BLACKLISTED);
        assert!(alpha_points_price <= partner_flex::get_max_cost_per_perk(control_settings), E_COST_EXCEEDS_LIMIT);
        assert!(
            partner_share_percentage >= partner_flex::get_min_partner_share_percentage(control_settings) &&
            partner_share_percentage <= partner_flex::get_max_partner_share_percentage(control_settings),
            E_INVALID_REVENUE_SHARE
        );

        if (option::is_some(&max_uses_per_claim)) {
            assert!(partner_flex::get_allow_consumable_perks(control_settings), E_CONSUMABLE_PERKS_DISABLED);
        };
        if (option::is_some(&expiration_timestamp_ms)) {
            assert!(partner_flex::get_allow_expiring_perks(control_settings), E_EXPIRING_PERKS_DISABLED);
        };
        if (generates_unique_claim_metadata) {
            assert!(partner_flex::get_allow_unique_metadata(control_settings), E_UNIQUE_METADATA_DISABLED);
        };

        let mut i = 0;
        while (i < vector::length(&tags)) {
            let tag = vector::borrow(&tags, i);
            assert!(
                vector::is_empty(partner_flex::get_allowed_tags(control_settings)) || 
                vector::contains(partner_flex::get_allowed_tags(control_settings), tag), 
                E_TAG_NOT_ALLOWED
            );
            assert!(!vector::contains(partner_flex::get_blacklisted_tags(control_settings), tag), E_TAG_BLACKLISTED);
            i = i + 1;
        };

        if (option::is_some(&max_claims)) {
            assert!(*option::borrow(&max_claims) <= partner_flex::get_max_claims_per_perk(control_settings), E_MAX_CLAIMS_EXCEEDS_LIMIT);
        };

        assert!(partner_flex::get_total_perks_created(partner_cap) < partner_flex::get_max_perks_per_partner(control_settings), E_MAX_PERKS_REACHED);
        assert!(partner_share_percentage <= 100, EInvalidRevenueSplitPercentage);

        let revenue_split = RevenueSplitPolicy {
            partner_share_percentage,
            platform_share_percentage: 100 - partner_share_percentage,
            partner_recipient_address: tx_context::sender(ctx),
            platform_recipient_address: @0xdeadbeef,
        };

        let mut def_metadata = DefinitionMetadataStore {
            id: object::new(ctx),
            marker: true,
        };

        let mut j = 0;
        assert!(vector::length(&definition_metadata_keys) == vector::length(&definition_metadata_values), 0);
        while (j < vector::length(&definition_metadata_keys)) {
            dynamic_field::add<String, String>(&mut def_metadata.id, *vector::borrow(&definition_metadata_keys, j), *vector::borrow(&definition_metadata_values, j));
            j = j + 1;
        };
        
        let tag_metadata = TagMetadataStore {
            id: object::new(ctx),
            marker: true,
        };
        
        // Store IDs before moving objects
        let def_metadata_id = object::id(&def_metadata);
        let tag_metadata_id = object::id(&tag_metadata);
        
        transfer::public_share_object(def_metadata);
        transfer::public_share_object(tag_metadata);

        let id = object::new(ctx);
        let perk_definition_id = object::uid_to_inner(&id);
        let perk_definition = PerkDefinition {
            id,
            name,
            description,
            creator_partner_cap_id: object::id(partner_cap),
            perk_type,
            usdc_price,
            current_alpha_points_price: alpha_points_price,
            last_price_update_timestamp_ms: clock::timestamp_ms(clock_obj),
            revenue_split_policy: revenue_split,
            max_claims,
            total_claims_count: 0,
            is_active,
            definition_metadata_id: def_metadata_id,
            generates_unique_claim_metadata,
            max_uses_per_claim,
            expiration_timestamp_ms,
            tags,
            tag_metadata_id: tag_metadata_id,
        };

        event::emit(PerkDefinitionCreated {
            perk_definition_id: perk_definition_id,
            creator_partner_cap_id: object::id(partner_cap),
            name: perk_definition.name,
            perk_type: perk_definition.perk_type,
            cost_alpha_points: alpha_points_price,
        });
        
        partner_flex::record_perk_created(partner_cap, ctx);
        transfer::share_object(perk_definition);
    }

    public entry fun claim_perk_configurable_split(
        config: &admin::Config,
        perk_definition: &mut PerkDefinition,
        partner_cap: &mut partner_flex::PartnerCapFlex,
        ledger: &mut ledger::Ledger,
        clock_obj: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(perk_definition.is_active, EPerkNotActive);
        assert!(object::id(partner_cap) == perk_definition.creator_partner_cap_id, ENotPerkCreator);
        
        // Update price if needed (using fixed pricing)
        if (clock::timestamp_ms(clock_obj) - perk_definition.last_price_update_timestamp_ms > 3600000) {
            update_perk_price_fixed(perk_definition, clock_obj, ctx);
        };

        // Check max claims
        if (option::is_some(&perk_definition.max_claims)) {
            assert!(perk_definition.total_claims_count < *option::borrow(&perk_definition.max_claims), EMaxClaimsReached);
        };

        let user_address = tx_context::sender(ctx);
        let cost = perk_definition.current_alpha_points_price;
        let epoch = tx_context::epoch(ctx);

        // Get configurable revenue split policy
        let revenue_policy = &perk_definition.revenue_split_policy;
        
        // Calculate splits using CONFIGURABLE percentages
        let partner_share = cost * (revenue_policy.partner_share_percentage as u64) / 100;
        let platform_share = cost * (revenue_policy.platform_share_percentage as u64) / 100;
        let remaining = cost - partner_share - platform_share;
        
        // Add remainder to platform share (deployer gets any rounding benefit)
        let deployer_share = platform_share + remaining;

        // Partner cap validations and minting (use partner share for quota validation)
        partner_flex::reset_daily_mint_throttle(partner_cap, epoch);
        partner_flex::validate_mint_quota(partner_cap, partner_share, epoch, ctx);

        // Spend user points
        ledger::internal_spend(ledger, user_address, cost, ctx);

        // Distribute revenue using CONFIGURABLE splits
        ledger::internal_earn(ledger, revenue_policy.partner_recipient_address, partner_share, ctx);
        ledger::internal_earn(ledger, admin::deployer_address(config), deployer_share, ctx);
        
        // Record points minted for partner
        partner_flex::record_points_minted(partner_cap, partner_share, epoch, ctx);

        // Update claims count
        perk_definition.total_claims_count = perk_definition.total_claims_count + 1;

        // Handle metadata
        let mut claim_metadata_id = option::none<ID>();
        if (perk_definition.generates_unique_claim_metadata) {
            let metadata_store = ClaimSpecificMetadataStore {
                id: object::new(ctx),
                marker: true,
            };
            let metadata_id = object::id(&metadata_store);
            transfer::public_share_object(metadata_store);
            claim_metadata_id = option::some(metadata_id);
        };

        // Create claimed perk
        let claimed_perk = ClaimedPerk {
            id: object::new(ctx),
            perk_definition_id: object::id(perk_definition),
            owner: user_address,
            claim_timestamp_ms: clock::timestamp_ms(clock_obj),
            status: string::utf8(b"ACTIVE"),
            claim_specific_metadata_id: claim_metadata_id,
            remaining_uses: perk_definition.max_uses_per_claim,
        };

        // Emit event with configurable split information
        event::emit(PerkClaimed {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            cost_alpha_points: cost,
            partner_points_share: partner_share,
            platform_points_share: deployer_share,
        });

        // Transfer to user
        transfer::public_transfer(claimed_perk, user_address);
    }

    public entry fun claim_perk_with_metadata_configurable_split(
        config: &admin::Config,
        perk_definition: &mut PerkDefinition,
        partner_cap: &mut partner_flex::PartnerCapFlex,
        ledger: &mut ledger::Ledger,
        metadata_key: String,
        metadata_value: String,
        clock_obj: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(perk_definition.is_active, EPerkNotActive);
        assert!(object::id(partner_cap) == perk_definition.creator_partner_cap_id, ENotPerkCreator);
        
        // Update price if needed (using fixed pricing)
        if (clock::timestamp_ms(clock_obj) - perk_definition.last_price_update_timestamp_ms > 3600000) {
            update_perk_price_fixed(perk_definition, clock_obj, ctx);
        };

        // Check max claims
        if (option::is_some(&perk_definition.max_claims)) {
            assert!(perk_definition.total_claims_count < *option::borrow(&perk_definition.max_claims), EMaxClaimsReached);
        };

        let user_address = tx_context::sender(ctx);
        let cost = perk_definition.current_alpha_points_price;
        let epoch = tx_context::epoch(ctx);

        // Get configurable revenue split policy
        let revenue_policy = &perk_definition.revenue_split_policy;
        
        // Calculate splits using CONFIGURABLE percentages
        let partner_share = cost * (revenue_policy.partner_share_percentage as u64) / 100;
        let platform_share = cost * (revenue_policy.platform_share_percentage as u64) / 100;
        let remaining = cost - partner_share - platform_share;
        
        // Add remainder to platform share (deployer gets any rounding benefit)
        let deployer_share = platform_share + remaining;

        // Partner cap validations and minting (use partner share for quota validation)
        partner_flex::reset_daily_mint_throttle(partner_cap, epoch);
        partner_flex::validate_mint_quota(partner_cap, partner_share, epoch, ctx);

        // Spend user points
        ledger::internal_spend(ledger, user_address, cost, ctx);

        // Distribute revenue using CONFIGURABLE splits
        ledger::internal_earn(ledger, revenue_policy.partner_recipient_address, partner_share, ctx);
        ledger::internal_earn(ledger, admin::deployer_address(config), deployer_share, ctx);
        
        // Record points minted for partner
        partner_flex::record_points_minted(partner_cap, partner_share, epoch, ctx);

        // Update claims count
        perk_definition.total_claims_count = perk_definition.total_claims_count + 1;

        // Handle claim-specific metadata
        let mut metadata_store = ClaimSpecificMetadataStore {
            id: object::new(ctx),
            marker: true,
        };
        
        // Add the provided metadata
        dynamic_field::add<String, String>(&mut metadata_store.id, metadata_key, metadata_value);
        
        let metadata_id = object::id(&metadata_store);
        transfer::public_share_object(metadata_store);

        // Create claimed perk with metadata
        let claimed_perk = ClaimedPerk {
            id: object::new(ctx),
            perk_definition_id: object::id(perk_definition),
            owner: user_address,
            claim_timestamp_ms: clock::timestamp_ms(clock_obj),
            status: string::utf8(b"ACTIVE"),
            claim_specific_metadata_id: option::some(metadata_id),
            remaining_uses: perk_definition.max_uses_per_claim,
        };

        // Emit event with configurable split information
        event::emit(PerkClaimed {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            cost_alpha_points: cost,
            partner_points_share: partner_share,
            platform_points_share: deployer_share,
        });

        // Transfer to user
        transfer::public_transfer(claimed_perk, user_address);
    }

    // === NEW USER-FRIENDLY CLAIM FUNCTIONS ===
    // These functions allow users to claim perks without providing business PartnerCapFlex

    /// User-friendly perk claiming function that doesn't require PartnerCapFlex
    /// Users can call this directly with just the PerkDefinition
    public entry fun claim_perk_by_user(
        config: &admin::Config,
        perk_definition: &mut PerkDefinition,
        ledger: &mut ledger::Ledger,
        clock_obj: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(perk_definition.is_active, EPerkNotActive);
        
        // Update price if needed (using fixed pricing)
        if (clock::timestamp_ms(clock_obj) - perk_definition.last_price_update_timestamp_ms > 3600000) {
            update_perk_price_fixed(perk_definition, clock_obj, ctx);
        };

        // Check max claims
        if (option::is_some(&perk_definition.max_claims)) {
            assert!(perk_definition.total_claims_count < *option::borrow(&perk_definition.max_claims), EMaxClaimsReached);
        };

        let user_address = tx_context::sender(ctx);
        let cost = perk_definition.current_alpha_points_price;

        // Get configurable revenue split policy
        let revenue_policy = &perk_definition.revenue_split_policy;
        
        // Calculate splits using CONFIGURABLE percentages
        let partner_share = cost * (revenue_policy.partner_share_percentage as u64) / 100;
        let platform_share = cost * (revenue_policy.platform_share_percentage as u64) / 100;
        let remaining = cost - partner_share - platform_share;
        let deployer_share = platform_share + remaining;

        // Spend user points
        ledger::internal_spend(ledger, user_address, cost, ctx);

        // Distribute revenue using CONFIGURABLE splits
        ledger::internal_earn(ledger, revenue_policy.partner_recipient_address, partner_share, ctx);
        ledger::internal_earn(ledger, admin::deployer_address(config), deployer_share, ctx);

        // Update claims count
        perk_definition.total_claims_count = perk_definition.total_claims_count + 1;

        // Handle metadata
        let mut claim_metadata_id = option::none<ID>();
        if (perk_definition.generates_unique_claim_metadata) {
            let metadata_store = ClaimSpecificMetadataStore {
                id: object::new(ctx),
                marker: true,
            };
            let metadata_id = object::id(&metadata_store);
            transfer::public_share_object(metadata_store);
            claim_metadata_id = option::some(metadata_id);
        };

        // Create claimed perk
        let claimed_perk = ClaimedPerk {
            id: object::new(ctx),
            perk_definition_id: object::id(perk_definition),
            owner: user_address,
            claim_timestamp_ms: clock::timestamp_ms(clock_obj),
            status: string::utf8(b"ACTIVE"),
            claim_specific_metadata_id: claim_metadata_id,
            remaining_uses: perk_definition.max_uses_per_claim,
        };

        // Emit event for business tracking (no quota validation for user-friendly version)
        event::emit(PerkClaimed {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            cost_alpha_points: cost,
            partner_points_share: partner_share,
            platform_points_share: deployer_share,
        });

        // Transfer to user
        transfer::public_transfer(claimed_perk, user_address);
    }

    /// User-friendly perk claiming with metadata function
    /// Users can call this directly with just the PerkDefinition and metadata
    public entry fun claim_perk_with_metadata_by_user(
        config: &admin::Config,
        perk_definition: &mut PerkDefinition,
        ledger: &mut ledger::Ledger,
        metadata_key: String,
        metadata_value: String,
        clock_obj: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(perk_definition.is_active, EPerkNotActive);
        
        // Update price if needed (using fixed pricing)
        if (clock::timestamp_ms(clock_obj) - perk_definition.last_price_update_timestamp_ms > 3600000) {
            update_perk_price_fixed(perk_definition, clock_obj, ctx);
        };

        // Check max claims
        if (option::is_some(&perk_definition.max_claims)) {
            assert!(perk_definition.total_claims_count < *option::borrow(&perk_definition.max_claims), EMaxClaimsReached);
        };

        let user_address = tx_context::sender(ctx);
        let cost = perk_definition.current_alpha_points_price;

        // Get configurable revenue split policy
        let revenue_policy = &perk_definition.revenue_split_policy;
        
        // Calculate splits using CONFIGURABLE percentages
        let partner_share = cost * (revenue_policy.partner_share_percentage as u64) / 100;
        let platform_share = cost * (revenue_policy.platform_share_percentage as u64) / 100;
        let remaining = cost - partner_share - platform_share;
        let deployer_share = platform_share + remaining;

        // Spend user points
        ledger::internal_spend(ledger, user_address, cost, ctx);

        // Distribute revenue using CONFIGURABLE splits
        ledger::internal_earn(ledger, revenue_policy.partner_recipient_address, partner_share, ctx);
        ledger::internal_earn(ledger, admin::deployer_address(config), deployer_share, ctx);

        // Update claims count
        perk_definition.total_claims_count = perk_definition.total_claims_count + 1;

        // Handle claim-specific metadata
        let mut metadata_store = ClaimSpecificMetadataStore {
            id: object::new(ctx),
            marker: true,
        };
        
        // Add the provided metadata
        dynamic_field::add<String, String>(&mut metadata_store.id, metadata_key, metadata_value);
        
        let metadata_id = object::id(&metadata_store);
        transfer::public_share_object(metadata_store);

        // Create claimed perk with metadata
        let claimed_perk = ClaimedPerk {
            id: object::new(ctx),
            perk_definition_id: object::id(perk_definition),
            owner: user_address,
            claim_timestamp_ms: clock::timestamp_ms(clock_obj),
            status: string::utf8(b"ACTIVE"),
            claim_specific_metadata_id: option::some(metadata_id),
            remaining_uses: perk_definition.max_uses_per_claim,
        };

        // Emit event for business tracking
        event::emit(PerkClaimed {
            claimed_perk_id: object::id(&claimed_perk),
            perk_definition_id: object::id(perk_definition),
            user_address,
            partner_cap_id: perk_definition.creator_partner_cap_id,
            cost_alpha_points: cost,
            partner_points_share: partner_share,
            platform_points_share: deployer_share,
        });

        // Transfer to user
        transfer::public_transfer(claimed_perk, user_address);
    }

    // === END NEW USER-FRIENDLY CLAIM FUNCTIONS ===

    public entry fun set_claim_metadata(
        claimed_perk: &ClaimedPerk,
        metadata_store: &mut ClaimSpecificMetadataStore,
        key: String,
        value: String,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == claimed_perk.owner, ENotOwner);
        assert!(option::is_some(&claimed_perk.claim_specific_metadata_id), ENoMetadata);
        assert!(*option::borrow(&claimed_perk.claim_specific_metadata_id) == object::id(metadata_store), EWrongMetadata);

        if (dynamic_field::exists_(&metadata_store.id, key)) {
            let mut_val: &mut String = dynamic_field::borrow_mut(&mut metadata_store.id, key);
            *mut_val = value;
        } else {
            dynamic_field::add(&mut metadata_store.id, key, value);
        };
    }
}