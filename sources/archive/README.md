# Sources Archive

This folder contains **original contract files** that were disabled during the audit preparation process.

## Contents

### Original v1 Contracts (*.move.disabled)
- `admin.move.disabled` - Original admin module
- `ledger.move.disabled` - Original ledger module
- `partner.move.disabled` - Original partner module
- `perk_manager.move.disabled` - Original perk manager
- `generation_manager.move.disabled` - Original generation manager
- `integration.move.disabled` - Original integration module
- `oracle.move.disabled` - Original oracle module
- Plus other original v1 modules (escrow, loan, staking, etc.)

### Enhanced v2/v3 Contracts (*.move.disabled)
- `admin_v2.move.disabled` - Enhanced admin with governance
- `ledger_v2.move.disabled` - Enhanced ledger with APY calculations
- `partner_v3.move.disabled` - Enhanced partner with DeFi integration
- `perk_manager_v2.move.disabled` - Enhanced perk manager with real-time pricing
- `generation_manager_v2.move.disabled` - Enhanced generation manager with webhooks
- `integration_v2.move.disabled` - Enhanced integration with asset redemption
- `oracle_v2.move.disabled` - Enhanced oracle with multi-source feeds

### Backup Files (*.backup)
- `*_v2.move.v2_backup` - Exact copies of v2 contracts before disabling
- `*_v3.move.v3_backup` - Exact copies of v3 contracts before disabling

## Purpose

These files are preserved to:
1. **Maintain full git history** of the protocol development
2. **Enable comparison** between original and simplified versions
3. **Support future development** when complex features are re-added
4. **Provide audit trail** of what was removed during simplification

## Audit Scope

⚠️ **These files are OUT OF AUDIT SCOPE** ⚠️

The security audit focuses exclusively on the **simplified contracts** in the parent `sources/` directory:
- `admin_simple.move`
- `ledger_simple.move` 
- `partner_simple.move`
- `perk_simple.move`
- `generation_simple.move`
- `integration_simple.move`
- `oracle_simple.move`

## Documentation

For detailed analysis of what was removed vs. preserved, see:
- `../CRITICAL_BUSINESS_LOGIC_AUDIT.md`
- `../simplification/*.md`
