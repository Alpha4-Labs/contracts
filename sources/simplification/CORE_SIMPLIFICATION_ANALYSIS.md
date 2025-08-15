# Alpha Points Core Simplification Analysis

## 🎯 Core B2B Platform Requirements

**KEEP:**
- ✅ Vaulting USDC assets
- ✅ TVL backing calculations  
- ✅ PartnerCap creation & updating
- ✅ Perk creation, updates & redemption
- ✅ Point minting/burning/tracking
- ✅ Integration endpoints for partners
- ✅ Oracle price feeds
- ✅ Emergency controls

**REMOVE:**
- ❌ Loan logic (entire loan system)
- ❌ Staking logic (time-based rewards)
- ❌ Governance logic (multi-sig, proposals, voting)
- ❌ Time-release reward calculations
- ❌ APY calculations and complex reward math
- ❌ DeFi integration (yield farming)

## 📊 Module Simplification Summary

| Module | Current Lines | Simplified Lines | Complexity Reduction |
|--------|---------------|------------------|---------------------|
| `admin_v2.move` | 994 | 150 | 85% |
| `ledger_v2.move` | 1,260 | 400 | 68% |
| `partner_v3.move` | 534 | 300 | 44% |
| `perk_manager_v2.move` | 1,252 | 800 | 36% |
| `generation_manager_v2.move` | 1,283 | 600 | 53% |
| `oracle_v2.move` | 489 | 250 | 49% |
| `integration_v2.move` | 199 | 100 | 50% |
| **TOTAL** | **6,011** | **2,600** | **57%** |

## 🔗 Core Module Dependencies

```
admin_simple.move (150 lines)
├── Provides: points_per_usd, treasury_address, pause controls
├── Used by: ALL other modules
└── Dependencies: None

ledger_simple.move (400 lines)  
├── Provides: mint_points(), burn_points(), get_balance()
├── Used by: partner_simple, perk_simple, integration_simple
└── Dependencies: admin_simple

partner_simple.move (300 lines)
├── Provides: create_partner(), vault management, quota tracking
├── Used by: perk_simple, integration_simple
└── Dependencies: admin_simple, ledger_simple

oracle_simple.move (250 lines)
├── Provides: get_price(), price validation
├── Used by: perk_simple
└── Dependencies: admin_simple

perk_simple.move (800 lines)
├── Provides: create_perk(), claim_perk(), revenue distribution
├── Used by: integration_simple (optional)
└── Dependencies: admin_simple, ledger_simple, partner_simple, oracle_simple

integration_simple.move (100 lines)
├── Provides: partner integration endpoints
├── Used by: External partner applications
└── Dependencies: admin_simple, ledger_simple, partner_simple

generation_simple.move (600 lines)
├── Provides: action registration, execution endpoints
├── Used by: External partner applications  
└── Dependencies: admin_simple, ledger_simple, partner_simple
```

## 🎯 Estimated Audit Savings

**Current Weighted Complexity:** 40,874 equivalent lines
**Simplified Weighted Complexity:** ~8,500 equivalent lines
**Audit Cost Reduction:** ~$55,000 (65% savings)
**New Estimated Cost:** ~$29,000
