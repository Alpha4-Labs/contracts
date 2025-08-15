/// Module that holds the underlying staked assets (Coin<T>) securely.
module alpha_points::escrow {
    // use sui::object; // Removed as it is a duplicate alias provided by default
    use sui::coin;
    use sui::balance;
    // use sui::transfer; // Removed as it is a duplicate alias provided by default
    // use sui::tx_context; // Removed as it is a duplicate alias provided by default
    use sui::event;
    
    use alpha_points::admin::GovernCap;
    
    // Error constants
    const EInsufficientFunds: u64 = 1;
    
    /// Shared object holding deposited coins of type T
    public struct EscrowVault<phantom T> has key {
        id: object::UID,
        balance: balance::Balance<T>
    }
    
    // Events
    public struct VaultCreated<phantom T> has copy, drop {
        id: object::ID // Using ID instead of UID for copy, drop compatibility
    }
    
    public struct AssetDeposited<phantom T> has copy, drop {
        vault_id: object::ID, // Using ID instead of UID
        amount: u64,
        depositor: address
    }
    
    public struct AssetWithdrawn<phantom T> has copy, drop {
        vault_id: object::ID, // Using ID instead of UID
        amount: u64,
        recipient: address
    }
    
    // === Test-only functions ===
    #[test_only]
    /// Helper function for tests to call deposit
    public fun test_deposit<T>(
        vault: &mut EscrowVault<T>, 
        _gov_cap: &GovernCap,
        coin: coin::Coin<T>,
        ctx: &tx_context::TxContext
    ) {
        deposit(vault, coin, ctx);
    }
    
    #[test_only]
    /// Helper function for tests to call withdraw
    public fun test_withdraw<T>(
        vault: &mut EscrowVault<T>, 
        _gov_cap: &GovernCap,
        amount: u64,
        recipient: address,
        ctx: &mut tx_context::TxContext
    ) {
        withdraw(vault, amount, recipient, ctx);
    }
    
    // === Core module functions ===
    
    /// Creates and shares a new EscrowVault for asset T
    public entry fun create_escrow_vault<T>(
        _gov_cap: &GovernCap,
        ctx: &mut tx_context::TxContext
    ) {
        let id = object::new(ctx);
        
        // Create vault with empty balance
        let vault = EscrowVault<T> {
            id,
            balance: balance::zero()
        };
        
        // Emit event - use ID instead of UID
        event::emit(VaultCreated<T> { 
            id: object::uid_to_inner(&vault.id)
        });
        
        // Share the vault
        transfer::share_object(vault);
    }
    
    /// Adds coin to vault.balance
    public(package) fun deposit<T>(
        vault: &mut EscrowVault<T>,
        coin: coin::Coin<T>,
        ctx: &tx_context::TxContext
    ) {
        let amount = coin::value(&coin);
        let depositor = tx_context::sender(ctx);
        
        // Add coin to balance
        let coin_balance = coin::into_balance(coin);
        balance::join(&mut vault.balance, coin_balance);
        
        // Emit event - use ID for vault_id
        event::emit(AssetDeposited<T> {
            vault_id: object::uid_to_inner(&vault.id),
            amount,
            depositor
        });
    }
    
    /// Removes amount from vault.balance, creates Coin<T>, transfers to recipient
    public(package) fun withdraw<T>(
        vault: &mut EscrowVault<T>,
        amount: u64,
        recipient: address,
        ctx: &mut tx_context::TxContext
    ) {
        // Check sufficient funds
        assert!(balance::value(&vault.balance) >= amount, EInsufficientFunds);
        
        // Take coins from balance
        let withdrawn_balance = balance::split(&mut vault.balance, amount);
        let coin = coin::from_balance(withdrawn_balance, ctx);
        
        // Transfer to recipient
        transfer::public_transfer(coin, recipient);
        
        // Emit event - use ID for vault_id
        event::emit(AssetWithdrawn<T> {
            vault_id: object::uid_to_inner(&vault.id),
            amount,
            recipient
        });
    }
    
    /// Returns the total value in the vault
    public fun total_value<T>(vault: &EscrowVault<T>): u64 {
        balance::value(&vault.balance)
    }

    /// Returns a reference to the EscrowVault's UID.
    public fun vault_uid<T>(vault: &EscrowVault<T>): &object::UID {
        &vault.id
    }
}