/// Alpha Points Integration Infrastructure V2 - Partner System Integration
/// 
/// Core Purpose: Enable partners to integrate Alpha Points into THEIR systems
/// NOT a campaign platform like Galxe - this is backend infrastructure for partner integration
/// 
/// Key Architecture:
/// 1. PARTNER INTEGRATION - Partners register their apps/systems with us
/// 2. ACTION REGISTRATION - Partners define which actions in their system mint points
/// 3. SECURE ENDPOINTS - Partners call our contracts from their apps when users complete actions
/// 4. VALIDATION & QUOTAS - Ensure partners can only mint points they're authorized to mint
/// 5. DEVELOPER FRIENDLY - Easy integration with webhooks, APIs, and SDKs
module alpha_points::generation_manager_v2 {
    use std::string::{Self, String};

    use std::option;
    
    use sui::object;
    use sui::tx_context;
    use sui::transfer;
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};


    use sui::bcs;
    
    // Import our fixed v2 modules
    use alpha_points::admin_v2::{Self, ConfigV2, AdminCapV2};
    use alpha_points::ledger_v2::{Self, LedgerV2};

    use alpha_points::partner_v3::{Self, PartnerCapV3, PartnerVault};
    
    // =================== CONSTANTS ===================
    
    // Integration limits and validation
    const MAX_ACTION_NAME_LENGTH: u64 = 100;         // Max length for action names
    const MAX_ACTION_DESCRIPTION_LENGTH: u64 = 500;  // Max description length
    const MAX_CONTEXT_DATA_LENGTH: u64 = 1000;       // Max context data size
    const MAX_ACTIONS_PER_PARTNER: u64 = 50;         // Max actions per partner
    const MAX_WEBHOOK_URL_LENGTH: u64 = 500;         // Max webhook URL length
    
    // Points minting limits
    const MIN_POINTS_PER_ACTION: u64 = 1;            // Minimum points per action
    const MAX_POINTS_PER_ACTION: u64 = 10000;        // Maximum points per action
    const MAX_DAILY_MINTS_PER_ACTION: u64 = 1000;    // Daily minting limit per action
    const MAX_MONTHLY_MINTS_PER_PARTNER: u64 = 100000; // Monthly partner limit
    
    // Rate limiting and security
    const RATE_LIMIT_WINDOW_MS: u64 = 60000;         // 1 minute rate limit window
    const MAX_REQUESTS_PER_WINDOW: u64 = 100;        // Max requests per window
    const MIN_ACTION_COOLDOWN_MS: u64 = 1000;        // 1 second min cooldown between actions

    
    // Integration security




    
    // =================== ERROR CONSTANTS ===================
    
    const EUnauthorized: u64 = 3001;

    const EActionNotActive: u64 = 3003;
    const ERateLimitExceeded: u64 = 3004;
    const EInvalidActionName: u64 = 3005;
    const EInvalidPointsAmount: u64 = 3006;
    const EMaxActionsReached: u64 = 3007;
    const EInvalidContextData: u64 = 3008;
    const EDailyLimitExceeded: u64 = 3009;
    const EMonthlyLimitExceeded: u64 = 3010;
    const EActionCooldownActive: u64 = 3011;
    const EInvalidWebhookUrl: u64 = 3012;


    const EPartnerIntegrationPaused: u64 = 3015;
    const EDuplicateActionName: u64 = 3016;

    const EInvalidUserAddress: u64 = 3018;
    const EActionExpired: u64 = 3019;
    const EContextDataTooLarge: u64 = 3020;
    const EIntegrationNotApproved: u64 = 3021;



    const EPartnerVaultInsufficient: u64 = 3025;
    
    // =================== CORE STRUCTS ===================
    
    /// Registered action that partners can trigger from their systems
    public struct RegisteredAction has key, store {
        id: UID,
        
        // === ACTION IDENTITY ===
        action_name: String,                  // Unique action name (e.g., "level_completed", "purchase_made")
        display_name: String,                 // Human-readable name for dashboards
        description: String,                  // Description of what this action represents
        category: String,                     // "gaming", "ecommerce", "social", "defi", etc.
        
        // === PARTNER OWNERSHIP ===
        partner_cap_id: ID,                   // PartnerCapV3 that created this action
        partner_address: address,             // Partner's address
        created_timestamp_ms: u64,            // When action was created
        created_by: address,                  // Who created the action
        
        // === POINTS CONFIGURATION ===
        points_per_execution: u64,            // Points minted per execution
        max_daily_executions: Option<u64>,    // Daily execution limit (None = unlimited)  
        max_monthly_executions: Option<u64>,  // Monthly execution limit (None = unlimited)
        max_total_executions: Option<u64>,    // Lifetime execution limit (None = unlimited)
        
        // === EXECUTION TRACKING ===
        total_executions: u64,                // Total times this action has been executed
        daily_executions: u64,                // Executions today
        monthly_executions: u64,              // Executions this month
        last_execution_ms: u64,               // Last execution timestamp
        daily_reset_time_ms: u64,             // When daily counter resets
        monthly_reset_time_ms: u64,           // When monthly counter resets
        
        // === OPERATIONAL CONTROLS ===
        is_active: bool,                      // Whether action can be executed
        requires_approval: bool,              // Whether executions need approval
        cooldown_period_ms: u64,              // Minimum time between executions (per user)
        integration_paused: bool,             // Emergency pause for this action
        
        // === CONTEXT & VALIDATION ===
        requires_context_data: bool,          // Whether execution requires context data
        context_schema: Option<String>,       // JSON schema for context validation (optional)
        allowed_user_segments: vector<String>, // User segments allowed to execute (empty = all)
        geographic_restrictions: vector<String>, // Restricted countries/regions
        
        // === INTEGRATION SETTINGS ===
        webhook_url: Option<String>,          // Webhook URL for notifications (optional)
        webhook_secret: Option<vector<u8>>,   // Secret for webhook authentication
        webhook_enabled: bool,                // Whether webhooks are enabled
        failed_webhook_count: u64,            // Number of consecutive webhook failures
        
        // === ANALYTICS & TRACKING ===
        total_points_minted: u64,             // Total points minted by this action
        unique_users_served: u64,             // Number of unique users who executed this action
        average_execution_interval_ms: u64,   // Average time between executions
        last_successful_execution_ms: u64,    // Last successful execution
        
        // === EXPIRATION & LIFECYCLE ===
        expiration_timestamp_ms: Option<u64>, // When action expires (None = never expires)
        auto_deactivate_on_expire: bool,     // Auto-deactivate when expired
        deprecation_notice: Option<String>,   // Deprecation notice for partners
        
        // === COMPLIANCE & SAFETY ===
        compliance_tags: vector<String>,      // Compliance-related tags
        risk_level: u8,                       // Risk level (1=Low, 2=Medium, 3=High)
        audit_trail_enabled: bool,            // Whether to maintain detailed audit trail
        data_retention_days: u64,             // How long to retain execution data
    }
    
    /// Partner integration registry and configuration
    public struct PartnerIntegration has key, store {
        id: UID,
        
        // === INTEGRATION IDENTITY ===
        integration_name: String,             // Partner's integration name
        partner_cap_id: ID,                   // Associated PartnerCapV3
        partner_address: address,             // Partner's address
        integration_type: String,             // "web_app", "mobile_app", "game", "api", etc.
        
        // === API AUTHENTICATION ===
        api_key: vector<u8>,                  // API key for authentication
        api_key_created_ms: u64,              // When API key was created
        api_key_expires_ms: Option<u64>,      // When API key expires (None = never)
        api_key_last_used_ms: u64,            // Last time API key was used
        
        // === REGISTERED ACTIONS ===
        registered_actions: Table<String, ID>, // action_name -> RegisteredAction ID
        active_actions_count: u64,            // Number of active actions
        
        // === RATE LIMITING ===
        rate_limit_window_start_ms: u64,      // Current rate limit window start
        requests_in_current_window: u64,      // Requests made in current window
        total_requests_all_time: u64,         // Total requests ever made
        
        // === MONTHLY QUOTAS ===
        monthly_points_minted: u64,           // Points minted this month
        monthly_executions: u64,              // Total executions this month
        monthly_quota_reset_ms: u64,          // When monthly quotas reset
        
        // === OPERATIONAL STATUS ===
        is_integration_active: bool,          // Whether integration is active
        is_approved: bool,                    // Whether integration is approved by admin
        integration_paused: bool,             // Emergency pause flag
        last_activity_ms: u64,                // Last integration activity
        
        // === WEBHOOK CONFIGURATION ===
        global_webhook_url: Option<String>,   // Global webhook URL for all actions
        webhook_secret: Option<vector<u8>>,   // Global webhook secret
        webhook_enabled: bool,                // Whether webhooks are enabled
        total_webhook_attempts: u64,          // Total webhook delivery attempts
        successful_webhook_deliveries: u64,   // Successful webhook deliveries
        
        // === ANALYTICS & MONITORING ===
        total_unique_users: u64,              // Total unique users served
        integration_health_score: u64,        // Health score (0-10000 bps)
        average_response_time_ms: u64,        // Average API response time
        error_rate_bps: u64,                  // Error rate in basis points
        
        // === COMPLIANCE & AUDIT ===
        compliance_level: String,             // "basic", "enhanced", "enterprise"
        audit_logging_enabled: bool,          // Whether audit logging is enabled
        data_residency_region: Option<String>, // Data residency requirements
        privacy_policy_url: Option<String>,   // Partner's privacy policy URL
        terms_of_service_url: Option<String>, // Partner's terms of service URL
        
        // === METADATA ===
        integration_metadata: vector<u8>,     // Additional integration metadata
        created_timestamp_ms: u64,            // When integration was created
        last_updated_ms: u64,                 // Last time integration was updated
    }
    
    /// Execution record for audit and analytics
    public struct ActionExecution has store, copy, drop {
        execution_id: vector<u8>,             // Unique execution ID (hash-based)
        action_id: ID,                        // RegisteredAction ID
        partner_cap_id: ID,                   // Partner that executed the action
        user_address: address,                // User who received the points
        points_minted: u64,                   // Points minted for this execution
        execution_timestamp_ms: u64,          // When execution occurred
        context_data: vector<u8>,             // Context data provided by partner
        execution_source: String,             // Source of execution (e.g., "web_app", "mobile_app")
        user_ip_hash: Option<vector<u8>>,     // Hashed user IP (for fraud detection)
        execution_metadata: vector<u8>,       // Additional execution metadata
        webhook_delivered: bool,              // Whether webhook was successfully delivered
        audit_trail_entry: bool,              // Whether this was logged to audit trail
    }
    
    /// Global integration registry and analytics
    public struct IntegrationRegistry has key {
        id: UID,
        
        // === REGISTRY ORGANIZATION ===
        integrations_by_partner: Table<ID, ID>,        // PartnerCap -> PartnerIntegration ID
        integrations_by_type: Table<String, vector<ID>>, // integration_type -> Integration IDs
        actions_by_category: Table<String, vector<ID>>, // category -> RegisteredAction IDs
        active_integrations: vector<ID>,               // Currently active integration IDs
        
        // === GLOBAL STATISTICS ===
        total_integrations_created: u64,      // Total integrations ever created
        total_actions_registered: u64,        // Total actions ever registered
        total_executions_processed: u64,      // Total executions ever processed
        total_points_minted_via_integrations: u64, // Total points minted via integrations
        total_unique_users_served: u64,       // Total unique users across all integrations
        
        // === DAILY OPERATIONS ===
        daily_executions: u64,                // Executions today
        daily_points_minted: u64,             // Points minted today
        daily_reset_timestamp_ms: u64,        // When daily counters reset
        
        // === HEALTH & MONITORING ===
        overall_system_health_score: u64,     // Overall system health (0-10000 bps)
        average_execution_latency_ms: u64,    // Average execution latency
        webhook_success_rate_bps: u64,        // Webhook success rate in basis points
        api_uptime_percentage: u64,           // API uptime percentage
        
        // === GOVERNANCE ===
        admin_cap_id: ID,                     // Admin capability for registry
        authorized_integrators: vector<address>, // Authorized integration managers
        approval_required_for_new_integrations: bool, // Whether new integrations need approval
        
        // === OPERATIONAL CONTROLS ===
        global_integration_pause: bool,       // Global emergency pause
        maintenance_mode: bool,               // Maintenance mode flag
        max_concurrent_executions: u64,       // Max concurrent executions
        current_concurrent_executions: u64,   // Current concurrent executions
        
        // === ANALYTICS ===
        top_performing_actions: vector<ID>,   // Best performing actions by volume  
        trending_integration_types: vector<String>, // Trending integration types
        monthly_growth_rate_bps: u64,         // Monthly growth rate in basis points
        retention_rate_90day_bps: u64,        // 90-day partner retention rate
    }
    
    /// Integration capability for authorized operations
    public struct IntegrationCapV2 has key, store {
        id: UID,
        registry_id: ID,                      // Associated registry ID
        permissions: u64,                     // Bit flags for permissions
        created_for: address,                 // Address this cap was created for
        expires_at_ms: Option<u64>,          // Optional expiration
        can_approve_integrations: bool,       // Permission to approve new integrations
        can_manage_actions: bool,             // Permission to manage actions
        can_emergency_pause: bool,            // Permission to emergency pause
        can_access_analytics: bool,           // Permission to access analytics
        can_modify_quotas: bool,              // Permission to modify partner quotas
    }
    
    // =================== EVENTS ===================
    
    /// Integration registration event
    public struct IntegrationRegistered has copy, drop {
        integration_id: ID,
        partner_cap_id: ID,
        partner_address: address,
        integration_name: String,
        integration_type: String,
        api_key_created: bool,
        webhook_configured: bool,
        approval_required: bool,
        created_timestamp_ms: u64,
    }
    
    /// Action registration event
    public struct ActionRegistered has copy, drop {
        action_id: ID,
        integration_id: ID,
        partner_cap_id: ID,
        action_name: String,
        display_name: String,
        category: String,
        points_per_execution: u64,
        max_daily_executions: Option<u64>,
        webhook_enabled: bool,
        requires_approval: bool,
        created_timestamp_ms: u64,
    }
    
    /// Action execution event (the core event when partners mint points)
    public struct ActionExecuted has copy, drop {
        execution_id: vector<u8>,
        action_id: ID,
        integration_id: ID,
        partner_cap_id: ID,
        user_address: address,
        action_name: String,
        points_minted: u64,
        execution_source: String,
        context_data_hash: Option<vector<u8>>,  // Hash of context data for privacy
        execution_timestamp_ms: u64,
        rate_limit_remaining: u64,
        daily_executions_remaining: Option<u64>,
        webhook_queued: bool,
    }
    
    /// Webhook delivery event
    public struct WebhookDelivered has copy, drop {
        action_id: ID,
        execution_id: vector<u8>,
        webhook_url: String,
        delivery_timestamp_ms: u64,
        response_status_code: u64,
        delivery_success: bool,
        retry_attempt: u64,
        total_delivery_time_ms: u64,
    }
    
    /// Integration health event
    public struct IntegrationHealthUpdated has copy, drop {
        integration_id: ID,
        partner_cap_id: ID,
        old_health_score: u64,
        new_health_score: u64,
        api_uptime_percentage: u64,
        webhook_success_rate_bps: u64,
        error_rate_bps: u64,
        recommended_actions: vector<String>,
        timestamp_ms: u64,
    }
    
    /// Rate limit warning event
    public struct RateLimitWarning has copy, drop {
        integration_id: ID,
        partner_cap_id: ID,
        current_requests: u64,
        rate_limit: u64,
        window_reset_time_ms: u64,
        severity: u8,                         // 1=Info, 2=Warning, 3=Critical
        recommended_action: String,
        timestamp_ms: u64,
    }
    
    /// Integration approval event
    public struct IntegrationApproved has copy, drop {
        integration_id: ID,
        partner_cap_id: ID,
        approved_by: address,
        approval_timestamp_ms: u64,
        approval_notes: Option<String>,
        compliance_level_assigned: String,
        initial_quotas_set: bool,
    }
    
    // =================== INITIALIZATION ===================
    
    /// Initialize the integration system
    fun init(_ctx: &mut TxContext) {
        // This will be called during package deployment
        // Main registry instance should be created via create_integration_registry_v2
    }
    
    /// Create the main integration registry
    public entry fun create_integration_registry_v2(
        config: &ConfigV2,
        admin_cap: &AdminCapV2,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate admin authorization
        assert!(admin_v2::is_admin(admin_cap, config), EUnauthorized);
        assert!(!admin_v2::is_paused(config), EPartnerIntegrationPaused);
        
        let admin_address = tx_context::sender(ctx);
        let current_time_ms = clock::timestamp_ms(clock);
        
        // Create registry
        let registry = IntegrationRegistry {
            id: object::new(ctx),
            
            // Registry organization
            integrations_by_partner: table::new(ctx),
            integrations_by_type: table::new(ctx),
            actions_by_category: table::new(ctx),
            active_integrations: vector::empty(),
            
            // Global statistics
            total_integrations_created: 0,
            total_actions_registered: 0,
            total_executions_processed: 0,
            total_points_minted_via_integrations: 0,
            total_unique_users_served: 0,
            
            // Daily operations
            daily_executions: 0,
            daily_points_minted: 0,
            daily_reset_timestamp_ms: current_time_ms + 86400000, // Next day
            
            // Health & monitoring
            overall_system_health_score: 10000, // Start at 100%
            average_execution_latency_ms: 0,
            webhook_success_rate_bps: 10000, // Start at 100%
            api_uptime_percentage: 10000, // Start at 100%
            
            // Governance
            admin_cap_id: admin_v2::get_admin_cap_uid_to_inner(admin_cap),
            authorized_integrators: vector::empty(),
            approval_required_for_new_integrations: false, // Auto-approve for testing
            
            // Operational controls
            global_integration_pause: false,
            maintenance_mode: false,
            max_concurrent_executions: 1000,
            current_concurrent_executions: 0,
            
            // Analytics
            top_performing_actions: vector::empty(),
            trending_integration_types: vector::empty(),
            monthly_growth_rate_bps: 0,
            retention_rate_90day_bps: 8000, // Start at 80%
        };
        
        let registry_id = object::uid_to_inner(&registry.id);
        
        // Create integration capability for admin
        let integration_cap = IntegrationCapV2 {
            id: object::new(ctx),
            registry_id,
            permissions: 0xFFFFFFFFFFFFFFFF, // Full permissions
            created_for: admin_address,
            expires_at_ms: option::none(),
            can_approve_integrations: true,
            can_manage_actions: true,
            can_emergency_pause: true,
            can_access_analytics: true,
            can_modify_quotas: true,
        };
        
        // Share registry and transfer capability
        transfer::share_object(registry);
        transfer::public_transfer(integration_cap, admin_address);
    }
    
    // =================== PARTNER INTEGRATION REGISTRATION ===================
    
    /// Partners register their integration with our system
    public entry fun register_partner_integration(
        registry: &mut IntegrationRegistry,
        partner_cap: &PartnerCapV3,
        partner_vault: &PartnerVault,
        integration_name: String,
        integration_type: String,
        webhook_url: Option<String>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate registry state
        assert!(!registry.global_integration_pause, EPartnerIntegrationPaused);
        assert!(!registry.maintenance_mode, EPartnerIntegrationPaused);
        
        let partner_address = tx_context::sender(ctx);
        let current_time_ms = clock::timestamp_ms(clock);
        
        // Validate partner authorization
        assert!(partner_v3::get_partner_address(partner_cap) == partner_address, EUnauthorized);
        assert!(!partner_v3::is_paused(partner_cap), EPartnerIntegrationPaused);
        
        // Validate vault ownership  
        assert!(partner_v3::get_vault_partner_address(partner_vault) == partner_address, EUnauthorized);
        
        // Input validation
        assert!(string::length(&integration_name) > 0 && string::length(&integration_name) <= MAX_ACTION_NAME_LENGTH, EInvalidActionName);
        
        // Validate webhook URL if provided
        if (option::is_some(&webhook_url)) {
            let url = option::borrow(&webhook_url);
            assert!(string::length(url) <= MAX_WEBHOOK_URL_LENGTH, EInvalidWebhookUrl);
        };
        
        let partner_cap_id = partner_v3::get_partner_cap_uid_to_inner(partner_cap);
        
        // Check if partner already has an integration
        assert!(!table::contains(&registry.integrations_by_partner, partner_cap_id), EDuplicateActionName);
        
        // Generate API key
        let api_key = generate_api_key(partner_cap_id, current_time_ms, ctx);
        
        // Create partner integration
        let integration = PartnerIntegration {
            id: object::new(ctx),
            
            // Integration identity
            integration_name,
            partner_cap_id,
            partner_address,
            integration_type,
            
            // API authentication
            api_key,
            api_key_created_ms: current_time_ms,
            api_key_expires_ms: option::none(), // API keys don't expire by default
            api_key_last_used_ms: 0,
            
            // Registered actions
            registered_actions: table::new(ctx),
            active_actions_count: 0,
            
            // Rate limiting
            rate_limit_window_start_ms: current_time_ms,
            requests_in_current_window: 0,
            total_requests_all_time: 0,
            
            // Monthly quotas
            monthly_points_minted: 0,
            monthly_executions: 0,
            monthly_quota_reset_ms: current_time_ms + (30 * 86400000), // 30 days
            
            // Operational status
            is_integration_active: true,
            is_approved: !registry.approval_required_for_new_integrations, // Auto-approve if not required
            integration_paused: false,
            last_activity_ms: current_time_ms,
            
            // Webhook configuration
            global_webhook_url: webhook_url,
            webhook_secret: if (option::is_some(&webhook_url)) { 
                option::some(generate_webhook_secret(partner_cap_id, current_time_ms)) 
            } else { 
                option::none() 
            },
            webhook_enabled: option::is_some(&webhook_url),
            total_webhook_attempts: 0,
            successful_webhook_deliveries: 0,
            
            // Analytics & monitoring
            total_unique_users: 0,
            integration_health_score: 10000, // Start at 100%
            average_response_time_ms: 0,
            error_rate_bps: 0,
            
            // Compliance & audit
            compliance_level: string::utf8(b"basic"),
            audit_logging_enabled: true,
            data_residency_region: option::none(),
            privacy_policy_url: option::none(),
            terms_of_service_url: option::none(),
            
            // Metadata
            integration_metadata: vector::empty(),
            created_timestamp_ms: current_time_ms,
            last_updated_ms: current_time_ms,
        };
        
        let integration_id = object::uid_to_inner(&integration.id);
        
        // Update registry
        table::add(&mut registry.integrations_by_partner, partner_cap_id, integration_id);
        
        // Add to integration type registry
        if (!table::contains(&registry.integrations_by_type, integration_type)) {
            table::add(&mut registry.integrations_by_type, integration_type, vector::empty());
        };
        let type_integrations = table::borrow_mut(&mut registry.integrations_by_type, integration_type);
        vector::push_back(type_integrations, integration_id);
        
        // Add to active integrations if approved
        if (integration.is_approved) {
            vector::push_back(&mut registry.active_integrations, integration_id);
        };
        
        // Update statistics
        registry.total_integrations_created = registry.total_integrations_created + 1;
        
        // Extract data before sharing object (Move ownership fix)
        let integration_name_value = integration.integration_name;
        let integration_type_value = integration.integration_type;
        
        // Share the integration
        transfer::share_object(integration);
        
        // Emit registration event with extracted data
        event::emit(IntegrationRegistered {
            integration_id,
            partner_cap_id,
            partner_address,
            integration_name: integration_name_value,
            integration_type: integration_type_value,
            api_key_created: true,
            webhook_configured: option::is_some(&webhook_url),
            approval_required: registry.approval_required_for_new_integrations,
            created_timestamp_ms: current_time_ms,
        });
    }
    
    // =================== ACTION REGISTRATION ===================
    
    /// Partners register actions that can be executed from their systems
    public entry fun register_action(
        registry: &mut IntegrationRegistry,
        integration: &mut PartnerIntegration,
        partner_cap: &PartnerCapV3,
        action_name: String,
        display_name: String,
        description: String,
        category: String,
        points_per_execution: u64,
        max_daily_executions: Option<u64>,
        cooldown_period_ms: u64,
        requires_context_data: bool,
        webhook_url: Option<String>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate authorization
        let partner_address = tx_context::sender(ctx);
        assert!(integration.partner_address == partner_address, EUnauthorized);
        assert!(partner_v3::get_partner_address(partner_cap) == partner_address, EUnauthorized);
        assert!(integration.partner_cap_id == partner_v3::get_partner_cap_uid_to_inner(partner_cap), EUnauthorized);
        assert!(integration.is_integration_active && integration.is_approved, EIntegrationNotApproved);
        
        let current_time_ms = clock::timestamp_ms(clock);
        
        // Input validation
        assert!(string::length(&action_name) > 0 && string::length(&action_name) <= MAX_ACTION_NAME_LENGTH, EInvalidActionName);
        assert!(string::length(&description) <= MAX_ACTION_DESCRIPTION_LENGTH, EInvalidActionName);
        assert!(points_per_execution >= MIN_POINTS_PER_ACTION && points_per_execution <= MAX_POINTS_PER_ACTION, EInvalidPointsAmount);
        assert!(cooldown_period_ms >= MIN_ACTION_COOLDOWN_MS, EActionCooldownActive);
        
        // Check action limits
        assert!(integration.active_actions_count < MAX_ACTIONS_PER_PARTNER, EMaxActionsReached);
        assert!(!table::contains(&integration.registered_actions, action_name), EDuplicateActionName);
        
        // Validate daily execution limits
        if (option::is_some(&max_daily_executions)) {
            let daily_limit = *option::borrow(&max_daily_executions);
            assert!(daily_limit <= MAX_DAILY_MINTS_PER_ACTION, EDailyLimitExceeded);
        };
        
        // Create registered action
        let action = RegisteredAction {
            id: object::new(ctx),
            
            // Action identity
            action_name,
            display_name,
            description,
            category,
            
            // Partner ownership
            partner_cap_id: integration.partner_cap_id,
            partner_address,
            created_timestamp_ms: current_time_ms,
            created_by: partner_address,
            
            // Points configuration
            points_per_execution,
            max_daily_executions,
            max_monthly_executions: option::some(MAX_MONTHLY_MINTS_PER_PARTNER / 10), // Default monthly limit
            max_total_executions: option::none(), // No total limit by default
            
            // Execution tracking
            total_executions: 0,
            daily_executions: 0,
            monthly_executions: 0,
            last_execution_ms: 0,
            daily_reset_time_ms: current_time_ms + 86400000, // Next day
            monthly_reset_time_ms: current_time_ms + (30 * 86400000), // Next month
            
            // Operational controls
            is_active: true,
            requires_approval: false, // Actions are auto-approved for approved integrations
            cooldown_period_ms,
            integration_paused: false,
            
            // Context & validation
            requires_context_data,
            context_schema: option::none(),
            allowed_user_segments: vector::empty(),
            geographic_restrictions: vector::empty(),
            
            // Integration settings - use action-specific webhook or fall back to global
            webhook_url: if (option::is_some(&webhook_url)) webhook_url else integration.global_webhook_url,
            webhook_secret: integration.webhook_secret,
            webhook_enabled: option::is_some(&webhook_url) || integration.webhook_enabled,
            failed_webhook_count: 0,
            
            // Analytics & tracking
            total_points_minted: 0,
            unique_users_served: 0,
            average_execution_interval_ms: 0,
            last_successful_execution_ms: 0,
            
            // Expiration & lifecycle
            expiration_timestamp_ms: option::none(),
            auto_deactivate_on_expire: true,
            deprecation_notice: option::none(),
            
            // Compliance & safety
            compliance_tags: vector::empty(),
            risk_level: 1, // Low risk by default
            audit_trail_enabled: true,
            data_retention_days: 365, // 1 year default retention
        };
        
        let action_id = object::uid_to_inner(&action.id);
        
        // Update integration
        table::add(&mut integration.registered_actions, action.action_name, action_id);
        integration.active_actions_count = integration.active_actions_count + 1;
        integration.last_updated_ms = current_time_ms;
        
        // Update registry
        if (!table::contains(&registry.actions_by_category, category)) {
            table::add(&mut registry.actions_by_category, category, vector::empty());
        };
        let category_actions = table::borrow_mut(&mut registry.actions_by_category, category);
        vector::push_back(category_actions, action_id);
        
        registry.total_actions_registered = registry.total_actions_registered + 1;
        
        // Extract data before sharing object (Move ownership fix)
        let action_name_value = action.action_name;
        let display_name_value = action.display_name;
        let category_value = action.category;
        let webhook_enabled_value = action.webhook_enabled;
        let requires_approval_value = action.requires_approval;
        
        // Share the action
        transfer::share_object(action);
        
        // Emit registration event with extracted data
        event::emit(ActionRegistered {
            action_id,
            integration_id: object::uid_to_inner(&integration.id),
            partner_cap_id: integration.partner_cap_id,
            action_name: action_name_value,
            display_name: display_name_value,
            category: category_value,
            points_per_execution,
            max_daily_executions,
            webhook_enabled: webhook_enabled_value,
            requires_approval: requires_approval_value,
            created_timestamp_ms: current_time_ms,
        });
    }
    
    // =================== ACTION EXECUTION (CORE INTEGRATION FUNCTION) ===================
    
    /// Execute a registered action from partner's system (MAIN INTEGRATION FUNCTION)
    /// This is the function partners call from their apps when users complete actions
    public entry fun execute_registered_action(
        registry: &mut IntegrationRegistry,
        integration: &mut PartnerIntegration,
        action: &mut RegisteredAction,
        partner_cap: &PartnerCapV3,
        partner_vault: &mut PartnerVault,
        ledger: &mut LedgerV2,
        user_address: address,
        context_data: vector<u8>,
        execution_source: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate system state
        assert!(!registry.global_integration_pause, EPartnerIntegrationPaused);
        assert!(integration.is_integration_active && integration.is_approved, EIntegrationNotApproved);
        assert!(action.is_active && !action.integration_paused, EActionNotActive);
        
        let current_time_ms = clock::timestamp_ms(clock);
        let partner_address = tx_context::sender(ctx);
        
        // Validate authorization (partners call this from their backend systems)
        assert!(integration.partner_address == partner_address, EUnauthorized);
        assert!(action.partner_address == partner_address, EUnauthorized);
        assert!(partner_v3::get_partner_address(partner_cap) == partner_address, EUnauthorized);
        
        // Validate user address
        assert!(user_address != @0x0, EInvalidUserAddress);
        
        // Check action expiration
        if (option::is_some(&action.expiration_timestamp_ms)) {
            assert!(current_time_ms <= *option::borrow(&action.expiration_timestamp_ms), EActionExpired);
        };
        
        // Rate limiting check
        check_rate_limits(integration, current_time_ms);
        
        // Reset daily/monthly counters if needed
        reset_time_based_counters(action, current_time_ms);
        
        // Check execution limits
        check_execution_limits(action, integration);
        
        // Validate context data
        if (action.requires_context_data) {
            assert!(vector::length(&context_data) > 0, EInvalidContextData);
        };
        assert!(vector::length(&context_data) <= MAX_CONTEXT_DATA_LENGTH, EContextDataTooLarge);
        
        // Check partner vault can support this minting
        let points_to_mint = action.points_per_execution;
        assert!(partner_v3::can_support_points_minting(partner_vault, points_to_mint), EPartnerVaultInsufficient);
        
        // Generate unique execution ID
        let execution_id = generate_execution_id(
            object::uid_to_inner(&action.id), 
            user_address, 
            current_time_ms, 
            &context_data
        );
        
        // MINT THE POINTS - This is the core action!
        ledger_v2::mint_points_with_controls(
            ledger, 
            user_address, 
            points_to_mint, 
            ledger_v2::partner_reward_type(),
            string::utf8(b"action_execution").into_bytes(),
            clock,
            ctx
        );
        
        // Update partner vault to reflect backing for minted points
        partner_v3::record_points_minting(partner_vault, points_to_mint, current_time_ms, ctx);
        
        // Create execution record
        let execution_record = ActionExecution {
            execution_id,
            action_id: object::uid_to_inner(&action.id),
            partner_cap_id: integration.partner_cap_id,
            user_address,
            points_minted: points_to_mint,
            execution_timestamp_ms: current_time_ms,
            context_data,
            execution_source,
            user_ip_hash: option::none(), // Could be enhanced to include IP hash for fraud detection
            execution_metadata: vector::empty(),
            webhook_delivered: false, // Will be updated if webhook succeeds
            audit_trail_entry: action.audit_trail_enabled,
        };
        
        // Update statistics
        update_execution_statistics(registry, integration, action, user_address, points_to_mint, current_time_ms);
        
        // Calculate rate limit remaining
        let rate_limit_remaining = MAX_REQUESTS_PER_WINDOW - integration.requests_in_current_window;
        let daily_executions_remaining = if (option::is_some(&action.max_daily_executions)) {
            option::some(*option::borrow(&action.max_daily_executions) - action.daily_executions)
        } else {
            option::none()
        };
        
        // Emit execution event
        event::emit(ActionExecuted {
            execution_id,
            action_id: object::uid_to_inner(&action.id),
            integration_id: object::uid_to_inner(&integration.id),
            partner_cap_id: integration.partner_cap_id,
            user_address,
            action_name: action.action_name,
            points_minted: points_to_mint,
            execution_source,
            context_data_hash: if (vector::length(&execution_record.context_data) > 0) {
                option::some(sui::hash::keccak256(&execution_record.context_data))
            } else {
                option::none()
            },
            execution_timestamp_ms: current_time_ms,
            rate_limit_remaining,
            daily_executions_remaining,
            webhook_queued: action.webhook_enabled,
        });
        
        // Queue webhook delivery if enabled (simplified - in production would use proper queue)
        if (action.webhook_enabled && option::is_some(&action.webhook_url)) {
            queue_webhook_delivery(action, &execution_record, current_time_ms);
        };
    }
    
    // =================== UTILITY FUNCTIONS ===================
    
    /// Generate API key for partner integration
    fun generate_api_key(partner_cap_id: ID, timestamp_ms: u64, ctx: &TxContext): vector<u8> {
        let mut key_data = vector::empty<u8>();
        vector::append(&mut key_data, bcs::to_bytes(&partner_cap_id));
        vector::append(&mut key_data, bcs::to_bytes(&timestamp_ms));
        vector::append(&mut key_data, bcs::to_bytes(&tx_context::sender(ctx)));
        sui::hash::keccak256(&key_data)
    }
    
    /// Generate webhook secret for secure webhook authentication
    fun generate_webhook_secret(partner_cap_id: ID, timestamp_ms: u64): vector<u8> {
        let mut secret_data = vector::empty<u8>();
        vector::append(&mut secret_data, bcs::to_bytes(&partner_cap_id));
        vector::append(&mut secret_data, bcs::to_bytes(&timestamp_ms));
        vector::append(&mut secret_data, b"webhook_secret");
        sui::hash::keccak256(&secret_data)
    }
    
    /// Generate unique execution ID
    fun generate_execution_id(
        action_id: ID, 
        user_address: address, 
        timestamp_ms: u64, 
        context_data: &vector<u8>
    ): vector<u8> {
        let mut id_data = vector::empty<u8>();
        vector::append(&mut id_data, bcs::to_bytes(&action_id));
        vector::append(&mut id_data, bcs::to_bytes(&user_address));
        vector::append(&mut id_data, bcs::to_bytes(&timestamp_ms));
        vector::append(&mut id_data, *context_data);
        sui::hash::keccak256(&id_data)
    }
    
    /// Check rate limits for integration
    fun check_rate_limits(integration: &mut PartnerIntegration, current_time_ms: u64) {
        // Reset rate limit window if needed
        if (current_time_ms >= integration.rate_limit_window_start_ms + RATE_LIMIT_WINDOW_MS) {
            integration.rate_limit_window_start_ms = current_time_ms;
            integration.requests_in_current_window = 0;
        };
        
        // Check rate limit
        assert!(integration.requests_in_current_window < MAX_REQUESTS_PER_WINDOW, ERateLimitExceeded);
        
        // Increment request count
        integration.requests_in_current_window = integration.requests_in_current_window + 1;
        integration.total_requests_all_time = integration.total_requests_all_time + 1;
    }
    
    /// Reset time-based counters if needed
    fun reset_time_based_counters(action: &mut RegisteredAction, current_time_ms: u64) {
        // Reset daily counter
        if (current_time_ms >= action.daily_reset_time_ms) {
            action.daily_executions = 0;
            action.daily_reset_time_ms = current_time_ms + 86400000; // Next day
        };
        
        // Reset monthly counter
        if (current_time_ms >= action.monthly_reset_time_ms) {
            action.monthly_executions = 0;
            action.monthly_reset_time_ms = current_time_ms + (30 * 86400000); // Next month
        };
    }
    
    /// Check execution limits
    fun check_execution_limits(action: &RegisteredAction, integration: &PartnerIntegration) {
        // Check daily limit
        if (option::is_some(&action.max_daily_executions)) {
            assert!(action.daily_executions < *option::borrow(&action.max_daily_executions), EDailyLimitExceeded);
        };
        
        // Check monthly limit for partner
        assert!(integration.monthly_executions < MAX_MONTHLY_MINTS_PER_PARTNER, EMonthlyLimitExceeded);
        
        // Check total executions limit
        if (option::is_some(&action.max_total_executions)) {
            assert!(action.total_executions < *option::borrow(&action.max_total_executions), EDailyLimitExceeded);
        };
    }
    
    /// Update execution statistics
    fun update_execution_statistics(
        registry: &mut IntegrationRegistry,
        integration: &mut PartnerIntegration,
        action: &mut RegisteredAction,
        user_address: address,
        points_minted: u64,
        current_time_ms: u64
    ) {
        // Update action statistics
        action.total_executions = action.total_executions + 1;
        action.daily_executions = action.daily_executions + 1;
        action.monthly_executions = action.monthly_executions + 1;
        action.total_points_minted = action.total_points_minted + points_minted;
        action.last_execution_ms = current_time_ms;
        action.last_successful_execution_ms = current_time_ms;
        
        // Update integration statistics
        integration.monthly_executions = integration.monthly_executions + 1;
        integration.monthly_points_minted = integration.monthly_points_minted + points_minted;
        integration.last_activity_ms = current_time_ms;
        
        // Update registry statistics
        registry.total_executions_processed = registry.total_executions_processed + 1;
        registry.total_points_minted_via_integrations = registry.total_points_minted_via_integrations + points_minted;
        registry.daily_executions = registry.daily_executions + 1;
        registry.daily_points_minted = registry.daily_points_minted + points_minted;
    }
    
    /// Queue webhook delivery (simplified implementation)
    fun queue_webhook_delivery(
        action: &mut RegisteredAction,
        execution_record: &ActionExecution,
        current_time_ms: u64
    ) {
        // In production, this would queue the webhook for asynchronous delivery
        // For now, we just update the attempt counter
        action.failed_webhook_count = 0; // Reset on successful queue
        
        // Emit webhook queued event (actual delivery would happen off-chain)
        event::emit(WebhookDelivered {
            action_id: object::uid_to_inner(&action.id),
            execution_id: execution_record.execution_id,
            webhook_url: *option::borrow(&action.webhook_url),
            delivery_timestamp_ms: current_time_ms,
            response_status_code: 0, // Would be set by actual webhook delivery
            delivery_success: true, // Assume success for queuing
            retry_attempt: 0,
            total_delivery_time_ms: 0,
        });
    }
    
    // =================== VIEW FUNCTIONS ===================
    
    /// Get integration details
    public fun get_integration_info(integration: &PartnerIntegration): (String, String, bool, bool, u64) {
        (
            integration.integration_name,
            integration.integration_type,
            integration.is_integration_active,
            integration.is_approved,
            integration.active_actions_count
        )
    }
    
    /// Get action details
    public fun get_action_info(action: &RegisteredAction): (String, String, String, u64, u64, bool) {
        (
            action.action_name,
            action.display_name,
            action.category,
            action.points_per_execution,
            action.total_executions,
            action.is_active
        )
    }
    
    /// Get integration statistics
    public fun get_integration_stats(integration: &PartnerIntegration): (u64, u64, u64, u64, u64) {
        (
            integration.total_requests_all_time,
            integration.monthly_executions,
            integration.monthly_points_minted,
            integration.total_unique_users,
            integration.integration_health_score
        )
    }
    
    /// Get registry statistics
    public fun get_registry_stats(registry: &IntegrationRegistry): (u64, u64, u64, u64, u64) {
        (
            registry.total_integrations_created,
            registry.total_actions_registered,
            registry.total_executions_processed,
            registry.total_points_minted_via_integrations,
            vector::length(&registry.active_integrations)
        )
    }

    /// Get registry ID for testing
    public fun get_registry_id(registry: &IntegrationRegistry): ID {
        object::uid_to_inner(&registry.id)
    }
    
    /// Check if partner can execute action
    public fun can_execute_action(
        integration: &PartnerIntegration,
        action: &RegisteredAction,
        current_time_ms: u64
    ): bool {
        // Basic checks
        if (!integration.is_integration_active || !integration.is_approved || !action.is_active) {
            return false
        };
        
        // Check rate limits
        if (integration.requests_in_current_window >= MAX_REQUESTS_PER_WINDOW) {
            return false
        };
        
        // Check daily limits
        if (option::is_some(&action.max_daily_executions)) {
            if (action.daily_executions >= *option::borrow(&action.max_daily_executions)) {
                return false
            };
        };
        
        // Check monthly limits
        if (integration.monthly_executions >= MAX_MONTHLY_MINTS_PER_PARTNER) {
            return false
        };
        
        // Check expiration
        if (option::is_some(&action.expiration_timestamp_ms)) {
            if (current_time_ms > *option::borrow(&action.expiration_timestamp_ms)) {
                return false
            };
        };
        
        true
    }
    
    /// Get actions by partner
    public fun get_partner_actions(_integration: &PartnerIntegration): vector<String> {
        let action_names = vector::empty<String>();
        // In a full implementation, we'd iterate through registered_actions
        // For now, return empty vector as placeholder
        action_names
    }
    
    // =================== ADMIN FUNCTIONS ===================
    
    /// Approve partner integration
    public entry fun approve_integration(
        registry: &mut IntegrationRegistry,
        integration: &mut PartnerIntegration,
        integration_cap: &IntegrationCapV2,
        approval_notes: Option<String>,
        compliance_level: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(integration_cap.registry_id == object::uid_to_inner(&registry.id), EUnauthorized);
        assert!(integration_cap.can_approve_integrations, EUnauthorized);
        
        let admin_address = tx_context::sender(ctx);
        let current_time_ms = clock::timestamp_ms(clock);
        
        integration.is_approved = true;
        integration.compliance_level = compliance_level;
        integration.last_updated_ms = current_time_ms;
        
        // Add to active integrations
        vector::push_back(&mut registry.active_integrations, object::uid_to_inner(&integration.id));
        
        event::emit(IntegrationApproved {
            integration_id: object::uid_to_inner(&integration.id),
            partner_cap_id: integration.partner_cap_id,
            approved_by: admin_address,
            approval_timestamp_ms: current_time_ms,
            approval_notes,
            compliance_level_assigned: integration.compliance_level,
            initial_quotas_set: true,
        });
    }
    
    /// Emergency pause all integrations
    public entry fun emergency_pause_all_integrations(
        registry: &mut IntegrationRegistry,
        integration_cap: &IntegrationCapV2,
        ctx: &mut TxContext
    ) {
        assert!(integration_cap.registry_id == object::uid_to_inner(&registry.id), EUnauthorized);
        assert!(integration_cap.can_emergency_pause, EUnauthorized);
        
        registry.global_integration_pause = true;
    }
    
    /// Resume all integrations
    public entry fun resume_all_integrations(
        registry: &mut IntegrationRegistry,
        integration_cap: &IntegrationCapV2,
        ctx: &mut TxContext
    ) {
        assert!(integration_cap.registry_id == object::uid_to_inner(&registry.id), EUnauthorized);
        assert!(integration_cap.can_emergency_pause, EUnauthorized);
        
        registry.global_integration_pause = false;
        registry.maintenance_mode = false;
    }
    
    // =================== TEST-ONLY FUNCTIONS ===================
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
    
    #[test_only]
    public fun create_test_integration_cap(registry_id: ID, ctx: &mut TxContext): IntegrationCapV2 {
        IntegrationCapV2 {
            id: object::new(ctx),
            registry_id,
            permissions: 0xFFFFFFFFFFFFFFFF,
            created_for: tx_context::sender(ctx),
            expires_at_ms: option::none(),
            can_approve_integrations: true,
            can_manage_actions: true,
            can_emergency_pause: true,
            can_access_analytics: true,
            can_modify_quotas: true,
        }
    }
    
    #[test_only]
    /// Create integration registry for testing
    public fun create_integration_registry_for_testing(
        _config: &ConfigV2,
        _admin_cap: &AdminCapV2,
        _clock: &Clock,
        ctx: &mut TxContext
    ): IntegrationRegistry {
        IntegrationRegistry {
            id: object::new(ctx),
            
            // === REGISTRY ORGANIZATION ===
            integrations_by_partner: table::new<ID, ID>(ctx),
            integrations_by_type: table::new<String, vector<ID>>(ctx),
            actions_by_category: table::new<String, vector<ID>>(ctx),
            active_integrations: vector::empty<ID>(),
            
            // === GLOBAL STATISTICS ===
            total_integrations_created: 0,
            total_actions_registered: 0,
            total_executions_processed: 0,
            total_points_minted_via_integrations: 0,
            total_unique_users_served: 0,
            
            // === DAILY OPERATIONS ===
            daily_executions: 0,
            daily_points_minted: 0,
            daily_reset_timestamp_ms: 0,
            
            // === HEALTH & MONITORING ===
            overall_system_health_score: 10000, // 100% health initially
            average_execution_latency_ms: 0,
            webhook_success_rate_bps: 10000, // 100% initially
            api_uptime_percentage: 100,
            
            // === GOVERNANCE ===
            admin_cap_id: object::id_from_address(@0x0), // Dummy for testing
            authorized_integrators: vector::empty<address>(),
            approval_required_for_new_integrations: false,
            
            // === OPERATIONAL CONTROLS ===
            global_integration_pause: false,
            maintenance_mode: false,
            max_concurrent_executions: 1000,
            current_concurrent_executions: 0,
            
            // === ANALYTICS ===
            top_performing_actions: vector::empty<ID>(),
            trending_integration_types: vector::empty<String>(),
            monthly_growth_rate_bps: 0,
            retention_rate_90day_bps: 8500, // 85% retention rate
        }
    }
} 