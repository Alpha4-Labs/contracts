/// Generation Manager Module - Manages Alpha Points generation opportunities
/// Integrates with partner_flex.move for partner authorization and ledger.move for point minting
/// Supports both embedded code execution and external URL redirects
/// Version: 1.0.0
module alpha_points::generation_manager {
    use std::string::{Self, String};
    use std::vector;
    use std::option::{Self, Option};
    
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};
    use sui::dynamic_field as df;
    
    use alpha_points::partner_flex::{Self, PartnerCapFlex};
    use alpha_points::ledger::{Self, Ledger, PointType};

    // === Error Constants ===
    const E_NOT_PARTNER_OWNER: u64 = 1001;
    const E_GENERATION_NOT_FOUND: u64 = 1002;
    const E_GENERATION_INACTIVE: u64 = 1003;
    const E_GENERATION_EXPIRED: u64 = 1004;
    const E_USER_EXECUTION_LIMIT_EXCEEDED: u64 = 1005;
    const E_TOTAL_EXECUTION_LIMIT_EXCEEDED: u64 = 1006;
    const E_INSUFFICIENT_QUOTA: u64 = 1007;
    const E_INVALID_EXECUTION_TYPE: u64 = 1008;
    const E_GENERATION_NOT_APPROVED: u64 = 1009;
    const E_INVALID_WALRUS_BLOB: u64 = 1010;
    const E_INVALID_TARGET_URL: u64 = 1011;
    const E_CODE_EXECUTION_FAILED: u64 = 1012;
    const E_SAFETY_SCORE_TOO_LOW: u64 = 1013;
    const E_PARTNER_CAP_PAUSED: u64 = 1014;

    // === Execution Types ===
    const EXECUTION_TYPE_EMBEDDED_CODE: u8 = 1;
    const EXECUTION_TYPE_EXTERNAL_URL: u8 = 2;
    const EXECUTION_TYPE_HYBRID: u8 = 3;

    // === Safety Constants ===
    const MIN_SAFETY_SCORE: u64 = 70; // Minimum safety score (0-100)
    const MAX_EXECUTION_TIME_MS: u64 = 30000; // 30 seconds max execution time

    // === Structs ===

    /// Represents a generation opportunity created by a partner
    public struct GenerationDefinition has key, store {
        id: UID,
        partner_cap_id: ID,                    // PartnerCapFlex that created this generation
        name: String,
        description: String,
        category: String,                      // e.g., "points_campaign", "engagement", "survey"
        execution_type: u8,                    // EMBEDDED_CODE, EXTERNAL_URL, or HYBRID
        quota_cost_per_execution: u64,         // Alpha Points quota cost per execution
        max_executions_per_user: Option<u64>,  // Per-user limit (None = unlimited)
        max_total_executions: Option<u64>,     // Global limit (None = unlimited)
        total_executions_count: u64,           // Current total executions
        is_active: bool,
        approved: bool,                        // Admin approval required for safety
        expiration_timestamp: Option<u64>,     // Expiration time in milliseconds
        created_timestamp: u64,
        tags: vector<String>,
        icon: Option<String>,                  // Icon URL or emoji
        estimated_completion_minutes: Option<u64>, // Estimated time to complete
        safety_score: Option<u64>,             // Safety score (0-100, higher = safer)
        
        // Embedded code fields
        walrus_blob_id: Option<String>,        // Walrus storage for code
        code_hash: Option<vector<u8>>,         // Hash of the code for verification
        template_type: Option<String>,         // e.g., "javascript", "wasm", "survey_json"
        
        // External URL fields
        target_url: Option<String>,            // Target URL for external generations
        redirect_type: Option<String>,         // "iframe", "new_tab", "popup"
        return_callback_url: Option<String>,   // URL to return to after completion
        requires_authentication: bool,         // Whether user must be authenticated
    }

    /// Tracks user execution history for rate limiting and quota management
    public struct UserExecutionRecord has store, copy, drop {
        user_address: address,
        generation_id: ID,
        execution_timestamp: u64,
        points_earned: u64,
        execution_metadata: String,            // JSON metadata about the execution
        completion_status: String,             // "completed", "failed", "timeout"
    }

    /// Shared registry of all generations for discovery
    public struct GenerationRegistry has key {
        id: UID,
        generations_by_partner: Table<ID, vector<ID>>, // PartnerCap -> Generation IDs
        generations_by_category: Table<String, vector<ID>>, // Category -> Generation IDs
        active_generations: vector<ID>,        // Currently active generation IDs
        total_generations_created: u64,
        total_executions_processed: u64,
    }

    // === Events ===

    public struct GenerationCreated has copy, drop {
        generation_id: ID,
        partner_cap_id: ID,
        name: String,
        category: String,
        execution_type: u8,
        quota_cost_per_execution: u64,
        created_by: address,
        created_timestamp: u64,
    }

    public struct GenerationExecuted has copy, drop {
        generation_id: ID,
        user_address: address,
        partner_cap_id: ID,
        points_earned: u64,
        execution_timestamp: u64,
        completion_status: String,
        execution_metadata: String,
    }

    public struct GenerationStatusChanged has copy, drop {
        generation_id: ID,
        partner_cap_id: ID,
        is_active: bool,
        approved: bool,
        changed_by: address,
        timestamp: u64,
    }

    public struct GenerationExpired has copy, drop {
        generation_id: ID,
        partner_cap_id: ID,
        total_executions: u64,
        expiration_timestamp: u64,
    }

    // === Dynamic Field Keys ===
    
    public struct UserExecutionHistoryKey has copy, drop, store {
        generation_id: ID,
    }

    // === Core Functions ===

    /// Initialize the generation manager system
    fun init(ctx: &mut TxContext) {
        let registry = GenerationRegistry {
            id: object::new(ctx),
            generations_by_partner: table::new(ctx),
            generations_by_category: table::new(ctx),
            active_generations: vector::empty(),
            total_generations_created: 0,
            total_executions_processed: 0,
        };
        transfer::share_object(registry);
    }

    /// Creates an embedded code generation opportunity
    public entry fun create_embedded_generation(
        partner_cap: &mut PartnerCapFlex,
        registry: &mut GenerationRegistry,
        name: String,
        description: String,
        category: String,
        walrus_blob_id: String,
        code_hash: vector<u8>,
        template_type: String,
        quota_cost_per_execution: u64,
        max_executions_per_user: Option<u64>,
        max_total_executions: Option<u64>,
        expiration_timestamp: Option<u64>,
        tags: vector<String>,
        icon: Option<String>,
        estimated_completion_minutes: Option<u64>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let partner_cap_id = object::uid_to_inner(partner_flex::id(partner_cap));
        
        // Verify sender owns the partner cap
        assert!(sender == partner_flex::partner_address(partner_cap), E_NOT_PARTNER_OWNER);
        
        // Verify partner cap is not paused
        assert!(!partner_flex::is_paused(partner_cap), E_PARTNER_CAP_PAUSED);
        
        // Validate walrus blob ID (basic validation)
        assert!(string::length(&walrus_blob_id) > 0, E_INVALID_WALRUS_BLOB);
        
        // Validate quota cost
        assert!(quota_cost_per_execution > 0, E_INSUFFICIENT_QUOTA);
        
        let current_timestamp = clock::timestamp_ms(clock);
        let generation_uid = object::new(ctx);
        let generation_id = object::uid_to_inner(&generation_uid);
        
        let generation = GenerationDefinition {
            id: generation_uid,
            partner_cap_id,
            name: name,
            description: description,
            category: category,
            execution_type: EXECUTION_TYPE_EMBEDDED_CODE,
            quota_cost_per_execution,
            max_executions_per_user,
            max_total_executions,
            total_executions_count: 0,
            is_active: true,
            approved: false, // Requires admin approval for safety
            expiration_timestamp,
            created_timestamp: current_timestamp,
            tags,
            icon,
            estimated_completion_minutes,
            safety_score: option::none(), // Will be set by admin during approval
            walrus_blob_id: option::some(walrus_blob_id),
            code_hash: option::some(code_hash),
            template_type: option::some(template_type),
            target_url: option::none(),
            redirect_type: option::none(),
            return_callback_url: option::none(),
            requires_authentication: false,
        };

        // Update registry
        update_registry_on_creation(registry, generation_id, partner_cap_id, &category);
        
        // Record perk creation in partner stats
        partner_flex::record_perk_created(partner_cap, ctx);

        event::emit(GenerationCreated {
            generation_id,
            partner_cap_id,
            name: name,
            category: category,
            execution_type: EXECUTION_TYPE_EMBEDDED_CODE,
            quota_cost_per_execution,
            created_by: sender,
            created_timestamp: current_timestamp,
        });

        transfer::share_object(generation);
    }

    /// Creates an external URL generation opportunity
    public entry fun create_external_generation(
        partner_cap: &mut PartnerCapFlex,
        registry: &mut GenerationRegistry,
        name: String,
        description: String,
        category: String,
        target_url: String,
        redirect_type: String,
        return_callback_url: Option<String>,
        requires_authentication: bool,
        quota_cost_per_execution: u64,
        max_executions_per_user: Option<u64>,
        max_total_executions: Option<u64>,
        expiration_timestamp: Option<u64>,
        tags: vector<String>,
        icon: Option<String>,
        estimated_completion_minutes: Option<u64>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let partner_cap_id = object::uid_to_inner(partner_flex::id(partner_cap));
        
        // Verify sender owns the partner cap
        assert!(sender == partner_flex::partner_address(partner_cap), E_NOT_PARTNER_OWNER);
        
        // Verify partner cap is not paused
        assert!(!partner_flex::is_paused(partner_cap), E_PARTNER_CAP_PAUSED);
        
        // Validate target URL (basic validation)
        assert!(string::length(&target_url) > 0, E_INVALID_TARGET_URL);
        
        // Validate quota cost
        assert!(quota_cost_per_execution > 0, E_INSUFFICIENT_QUOTA);
        
        let current_timestamp = clock::timestamp_ms(clock);
        let generation_uid = object::new(ctx);
        let generation_id = object::uid_to_inner(&generation_uid);
        
        let generation = GenerationDefinition {
            id: generation_uid,
            partner_cap_id,
            name: name,
            description: description,
            category: category,
            execution_type: EXECUTION_TYPE_EXTERNAL_URL,
            quota_cost_per_execution,
            max_executions_per_user,
            max_total_executions,
            total_executions_count: 0,
            is_active: true,
            approved: true, // External URLs can be auto-approved (safer)
            expiration_timestamp,
            created_timestamp: current_timestamp,
            tags,
            icon,
            estimated_completion_minutes,
            safety_score: option::some(85), // Default safe score for external URLs
            walrus_blob_id: option::none(),
            code_hash: option::none(),
            template_type: option::none(),
            target_url: option::some(target_url),
            redirect_type: option::some(redirect_type),
            return_callback_url,
            requires_authentication,
        };

        // Update registry
        update_registry_on_creation(registry, generation_id, partner_cap_id, &category);
        
        // Record perk creation in partner stats
        partner_flex::record_perk_created(partner_cap, ctx);

        event::emit(GenerationCreated {
            generation_id,
            partner_cap_id,
            name: name,
            category: category,
            execution_type: EXECUTION_TYPE_EXTERNAL_URL,
            quota_cost_per_execution,
            created_by: sender,
            created_timestamp: current_timestamp,
        });

        transfer::share_object(generation);
    }

    /// Executes a generation and awards points to the user
    public entry fun execute_generation(
        generation: &mut GenerationDefinition,
        partner_cap: &mut PartnerCapFlex,
        ledger: &mut Ledger,
        user_address: address,
        execution_metadata: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_timestamp = clock::timestamp_ms(clock);
        let current_epoch = tx_context::epoch(ctx);
        let generation_id = object::uid_to_inner(&generation.id);
        
        // Validate generation is active and approved
        assert!(generation.is_active, E_GENERATION_INACTIVE);
        assert!(generation.approved, E_GENERATION_NOT_APPROVED);
        
        // Check expiration
        if (option::is_some(&generation.expiration_timestamp)) {
            let expiry = *option::borrow(&generation.expiration_timestamp);
            assert!(current_timestamp < expiry, E_GENERATION_EXPIRED);
        };
        
        // Check total execution limits
        if (option::is_some(&generation.max_total_executions)) {
            let max_total = *option::borrow(&generation.max_total_executions);
            assert!(generation.total_executions_count < max_total, E_TOTAL_EXECUTION_LIMIT_EXCEEDED);
        };
        
        // Check per-user execution limits
        if (option::is_some(&generation.max_executions_per_user)) {
            let max_per_user = *option::borrow(&generation.max_executions_per_user);
            let user_execution_count = get_user_execution_count(generation, user_address);
            assert!(user_execution_count < max_per_user, E_USER_EXECUTION_LIMIT_EXCEEDED);
        };
        
        // Validate partner quota and record points minting
        partner_flex::validate_mint_quota(partner_cap, generation.quota_cost_per_execution, current_epoch, ctx);
        partner_flex::record_points_minted(partner_cap, generation.quota_cost_per_execution, current_epoch, ctx);
        
        // Mint points to user via ledger
        let stake_opt = option::none();
        ledger::mint_points(
            ledger,
            user_address,
            generation.quota_cost_per_execution,
            ledger::new_point_type_generic_reward(),
            ctx,
            &stake_opt,
            0, // default liq_share for generation execution
            clock
        );
        option::destroy_none(stake_opt);
        
        // Record user execution
        record_user_execution(
            generation,
            user_address,
            generation.quota_cost_per_execution,
            execution_metadata,
            string::utf8(b"completed"),
            current_timestamp,
            ctx
        );
        
        // Update generation stats
        generation.total_executions_count = generation.total_executions_count + 1;
        
        event::emit(GenerationExecuted {
            generation_id,
            user_address,
            partner_cap_id: generation.partner_cap_id,
            points_earned: generation.quota_cost_per_execution,
            execution_timestamp: current_timestamp,
            completion_status: string::utf8(b"completed"),
            execution_metadata,
        });
    }

    /// Sets the active status of a generation (partner owner only)
    public entry fun set_generation_active_status(
        generation: &mut GenerationDefinition,
        partner_cap: &PartnerCapFlex,
        is_active: bool,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let partner_cap_id = object::uid_to_inner(partner_flex::id(partner_cap));
        
        // Verify sender owns the partner cap and generation belongs to this partner
        assert!(sender == partner_flex::partner_address(partner_cap), E_NOT_PARTNER_OWNER);
        assert!(generation.partner_cap_id == partner_cap_id, E_NOT_PARTNER_OWNER);
        
        generation.is_active = is_active;
        
        event::emit(GenerationStatusChanged {
            generation_id: object::uid_to_inner(&generation.id),
            partner_cap_id,
            is_active,
            approved: generation.approved,
            changed_by: sender,
            timestamp: clock::timestamp_ms(clock),
        });
    }

    // === Admin Functions ===
    
    /// Approves a generation for execution (admin only)
    /// Note: In a production system, you'd want to pass an AdminCap here
    public entry fun approve_generation(
        generation: &mut GenerationDefinition,
        safety_score: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // TODO: Add AdminCap validation when admin system is integrated
        // assert!(has_admin_permission(admin_cap), E_NOT_ADMIN);
        
        assert!(safety_score <= 100, E_SAFETY_SCORE_TOO_LOW);
        assert!(safety_score >= MIN_SAFETY_SCORE, E_SAFETY_SCORE_TOO_LOW);
        
        generation.approved = true;
        generation.safety_score = option::some(safety_score);
        
        event::emit(GenerationStatusChanged {
            generation_id: object::uid_to_inner(&generation.id),
            partner_cap_id: generation.partner_cap_id,
            is_active: generation.is_active,
            approved: true,
            changed_by: tx_context::sender(ctx),
            timestamp: clock::timestamp_ms(clock),
        });
    }

    // === Helper Functions ===

    fun update_registry_on_creation(
        registry: &mut GenerationRegistry,
        generation_id: ID,
        partner_cap_id: ID,
        category: &String
    ) {
        // Add to partner's generations
        if (!table::contains(&registry.generations_by_partner, partner_cap_id)) {
            table::add(&mut registry.generations_by_partner, partner_cap_id, vector::empty());
        };
        let partner_generations = table::borrow_mut(&mut registry.generations_by_partner, partner_cap_id);
        vector::push_back(partner_generations, generation_id);
        
        // Add to category
        if (!table::contains(&registry.generations_by_category, *category)) {
            table::add(&mut registry.generations_by_category, *category, vector::empty());
        };
        let category_generations = table::borrow_mut(&mut registry.generations_by_category, *category);
        vector::push_back(category_generations, generation_id);
        
        // Update stats
        registry.total_generations_created = registry.total_generations_created + 1;
    }

    fun record_user_execution(
        generation: &mut GenerationDefinition,
        user_address: address,
        points_earned: u64,
        execution_metadata: String,
        completion_status: String,
        timestamp: u64,
        ctx: &mut TxContext
    ) {
        let key = UserExecutionHistoryKey {
            generation_id: object::uid_to_inner(&generation.id),
        };
        
        let execution_record = UserExecutionRecord {
            user_address,
            generation_id: object::uid_to_inner(&generation.id),
            execution_timestamp: timestamp,
            points_earned,
            execution_metadata,
            completion_status,
        };
        
        // Store execution history as dynamic field
        if (!df::exists_with_type<UserExecutionHistoryKey, vector<UserExecutionRecord>>(&generation.id, key)) {
            df::add(&mut generation.id, key, vector::empty<UserExecutionRecord>());
        };
        
        let execution_history = df::borrow_mut<UserExecutionHistoryKey, vector<UserExecutionRecord>>(&mut generation.id, key);
        vector::push_back(execution_history, execution_record);
    }

    fun get_user_execution_count(generation: &GenerationDefinition, user_address: address): u64 {
        let key = UserExecutionHistoryKey {
            generation_id: object::uid_to_inner(&generation.id),
        };
        
        if (!df::exists_with_type<UserExecutionHistoryKey, vector<UserExecutionRecord>>(&generation.id, key)) {
            return 0
        };
        
        let execution_history = df::borrow<UserExecutionHistoryKey, vector<UserExecutionRecord>>(&generation.id, key);
        let mut count = 0;
        let mut i = 0;
        let len = vector::length(execution_history);
        
        while (i < len) {
            let record = vector::borrow(execution_history, i);
            if (record.user_address == user_address) {
                count = count + 1;
            };
            i = i + 1;
        };
        
        count
    }

    // === View Functions ===

    public fun get_generation_info(generation: &GenerationDefinition): (
        String, // name
        String, // description
        String, // category
        u8,     // execution_type
        u64,    // quota_cost_per_execution
        u64,    // total_executions_count
        bool,   // is_active
        bool,   // approved
        u64     // created_timestamp
    ) {
        (
            generation.name,
            generation.description,
            generation.category,
            generation.execution_type,
            generation.quota_cost_per_execution,
            generation.total_executions_count,
            generation.is_active,
            generation.approved,
            generation.created_timestamp
        )
    }

    public fun get_generation_limits(generation: &GenerationDefinition): (
        Option<u64>, // max_executions_per_user
        Option<u64>, // max_total_executions
        Option<u64>  // expiration_timestamp
    ) {
        (
            generation.max_executions_per_user,
            generation.max_total_executions,
            generation.expiration_timestamp
        )
    }

    public fun get_generation_metadata(generation: &GenerationDefinition): (
        vector<String>, // tags
        Option<String>, // icon
        Option<u64>,    // estimated_completion_minutes
        Option<u64>     // safety_score
    ) {
        (
            generation.tags,
            generation.icon,
            generation.estimated_completion_minutes,
            generation.safety_score
        )
    }

    public fun get_embedded_generation_data(generation: &GenerationDefinition): (
        Option<String>,      // walrus_blob_id
        Option<vector<u8>>,  // code_hash
        Option<String>       // template_type
    ) {
        (
            generation.walrus_blob_id,
            generation.code_hash,
            generation.template_type
        )
    }

    public fun get_external_generation_data(generation: &GenerationDefinition): (
        Option<String>, // target_url
        Option<String>, // redirect_type
        Option<String>, // return_callback_url
        bool            // requires_authentication
    ) {
        (
            generation.target_url,
            generation.redirect_type,
            generation.return_callback_url,
            generation.requires_authentication
        )
    }

    public fun get_registry_stats(registry: &GenerationRegistry): (u64, u64) {
        (registry.total_generations_created, registry.total_executions_processed)
    }

    public fun get_partner_generations(registry: &GenerationRegistry, partner_cap_id: ID): vector<ID> {
        if (table::contains(&registry.generations_by_partner, partner_cap_id)) {
            *table::borrow(&registry.generations_by_partner, partner_cap_id)
        } else {
            vector::empty()
        }
    }

    public fun get_generations_by_category(registry: &GenerationRegistry, category: String): vector<ID> {
        if (table::contains(&registry.generations_by_category, category)) {
            *table::borrow(&registry.generations_by_category, category)
        } else {
            vector::empty()
        }
    }

    // === Test-only Functions ===

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}