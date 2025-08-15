# Tests Archive

This folder contains **original test files** that were disabled during the audit preparation process.

## Contents

### Original v2/v3 Test Suites (*.disabled)
- `admin_v2_*.disabled` - Comprehensive admin v2 test suites
- `ledger_v2_*.disabled` - Comprehensive ledger v2 test suites  
- `partner_v3_*.disabled` - Comprehensive partner v3 test suites
- `perk_manager_v2_*.disabled` - Comprehensive perk manager v2 test suites
- `generation_manager_v2_*.disabled` - Comprehensive generation manager v2 test suites
- `integration_v2_*.disabled` - Comprehensive integration v2 test suites
- `oracle_v2_*.disabled` - Comprehensive oracle v2 test suites

### Test Categories
- **Entry Tests** - Testing public entry functions
- **Comprehensive Tests** - Full module coverage tests
- **Coverage Tests** - Specific coverage enhancement tests
- **Security Tests** - Edge cases and security scenarios
- **Error Cases** - Comprehensive error condition testing

## Test Statistics

**Original Test Suite:**
- **37 test files** with thousands of individual test cases
- **Comprehensive coverage** of all v2/v3 features
- **Complex scenarios** including governance, staking, lending, DeFi integration

## Purpose

These files are preserved to:
1. **Maintain testing knowledge** for complex features
2. **Support future development** when features are re-added
3. **Provide testing patterns** and best practices
4. **Enable comparison** with simplified test approaches

## Current Audit Tests

⚠️ **These files are OUT OF AUDIT SCOPE** ⚠️

The security audit focuses on the **new simplified test suite** in the parent `tests/` directory:
- `core_simple_tests.move`
- `critical_admin_tests.move`
- `critical_ledger_tests.move`
- `advanced_coverage_tests.move`
- `extended_coverage_tests.move`
- `missing_coverage_tests.move`
- `generation_focused_tests.move`
- `perk_focused_tests.move`

**New Test Suite Statistics:**
- **8 active test files**
- **55 total tests** 
- **98.2% success rate** (54/55 passing)
- **Focused on core business logic** only

## Documentation

For detailed analysis of test coverage and approach, see:
- `../../CRITICAL_BUSINESS_LOGIC_AUDIT.md`
- `../../AUDIT_README.md`
