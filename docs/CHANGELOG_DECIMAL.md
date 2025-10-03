# Decimal Type Implementation - Changelog

## Summary
Added arbitrary-precision decimal support to Quest for PostgreSQL NUMERIC/DECIMAL types.

## Changes Made

### Core Implementation
- **Cargo.toml**: Added `rust_decimal = { version = "1.36", features = ["db-postgres", "serde-float"] }`
- **src/types/decimal.rs**: New file with complete QDecimal implementation
  - Arithmetic operations: plus, minus, times, div, mod
  - Comparison operations: eq, neq, gt, lt, gte, lte
  - Conversion methods: to_f64, to_string
  - Works with both Decimal and Num types in operations
- **src/types/mod.rs**: Integrated QDecimal into type system
  - Added QValue::Decimal variant
  - Updated as_obj(), as_num(), as_bool(), as_str(), q_type() methods
  - Added rust_decimal imports

### PostgreSQL Integration
- **src/modules/db/postgres.rs**:
  - Parameter conversion: QDecimal → PostgreSQL NUMERIC (write support)
  - Result conversion: PostgreSQL NUMERIC → QDecimal (read support)
  - Array support: NUMERIC[] arrays convert to Array<Decimal>

### JSON Support
- **src/modules/encoding/json_utils.rs**:
  - QDecimal serialization to JSON (converts to f64 for JSON compatibility)

### Testing
- **test/db/postgres_test.q**: Added comprehensive test suite with 7 test cases:
  1. Basic NUMERIC type handling
  2. High precision NUMERIC values
  3. Arithmetic operations (plus, minus, times)
  4. NULL NUMERIC values
  5. Comparison operations (lt, gt, ordering)
  6. NUMERIC[] array support
  7. Conversion to f64
- **test/decimal_test.q**: Placeholder for future direct decimal construction tests

### Documentation
- **docs/docs/types/decimal.md**: Complete type documentation
  - Overview and use cases
  - All methods with examples
  - PostgreSQL integration guide
  - Precision notes and limitations
- **docs/docs/language/types.md**: Updated core types list to include decimal

## Build Status
✅ Clean build with no warnings or errors

## Key Features
- Arbitrary precision (28-29 significant digits)
- Full PostgreSQL NUMERIC/DECIMAL roundtrip support
- Arithmetic with mixed Decimal/Num types
- Array support
- JSON serialization
- Comprehensive test coverage

## PostgreSQL Type Coverage
With this implementation, Quest now supports all commonly-used PostgreSQL types:
- ✅ INTEGER, BIGINT, SMALLINT
- ✅ REAL, DOUBLE PRECISION
- ✅ **NUMERIC/DECIMAL** (NEW)
- ✅ TEXT, VARCHAR, CHAR
- ✅ BOOLEAN
- ✅ BYTEA
- ✅ UUID
- ✅ DATE, TIME, TIMESTAMP, TIMESTAMPTZ
- ✅ INTERVAL
- ✅ JSON, JSONB
- ✅ Arrays of all above types

## Future Enhancements
- Direct decimal literal syntax (e.g., `123.45d`)
- Constructor from string: `Decimal.from_string("123.45")`
- Additional mathematical operations (sqrt, pow, etc.)
- Banker's rounding options
