# QEP-039: Documentation Improvements

**Number**: 039
**Status**: Draft
**Author**: Claude
**Created**: 2025-10-07

## Summary

After conducting an audit (2025-10-07), this QEP identifies **actual** documentation gaps and proposes a phased improvement plan. Key findings:

**Good news**: Much less work than initially estimated!
- ✅ **10 stdlib pages exist** but aren't linked in sidebar (quick wins)
- ✅ **Bytes type page exists** (just needs linking)
- ❌ Only **3 type pages need creation** (BigInt, Bool, Nil)

**Priorities**:
1. Add 11 existing pages to sidebar (1-2 hours)
2. Document recently implemented features (QEP-033, 034, 037)
3. Create 3 missing type pages
4. Add automated example testing
5. Expand organization (tutorials, cookbook)

**Deferred** (awaiting implementation):
- Decorators (QEP-003: not implemented)
- Logging (QEP-004: not implemented)

## Motivation

The Quest documentation has grown organically as features have been added. While it covers many topics, there are gaps in completeness, inconsistencies in organization, and areas where accuracy could be improved. A comprehensive review and improvement plan will ensure users can effectively learn and reference Quest's features.

This QEP identifies specific improvements needed across the documentation to make it more complete, accurate, well-organized, and consistent.

## Current State Analysis

**Note**: This analysis is based on an audit conducted on 2025-10-07 comparing existing documentation files in `docs/docs/` against the sidebar configuration in `docs/sidebars.ts`.

### Completeness Issues

1. **Missing Type Documentation**
   - ✅ `Bytes` - **EXISTS** but NOT in sidebar ([types/bytes.md](docs/docs/types/bytes.md))
   - ⚠️ `BigInt` type lacks comprehensive method documentation (no dedicated page)
   - ✅ `Uuid` - **EXISTS** but NOT in sidebar ([stdlib/uuid.md](docs/docs/stdlib/uuid.md))
   - ❌ `Nil` type has no dedicated page
   - ❌ `Bool` type has no dedicated page

2. **Incomplete Module Documentation**
   - **Existing docs NOT in sidebar** (10 pages orphaned):
     - ✅ `compress` - exists ([stdlib/compress.md](docs/docs/stdlib/compress.md))
     - ✅ `database` - exists ([stdlib/database.md](docs/docs/stdlib/database.md))
     - ✅ `html_templates` - exists ([stdlib/html_templates.md](docs/docs/stdlib/html_templates.md))
     - ✅ `http` - exists ([stdlib/http.md](docs/docs/stdlib/http.md))
     - ✅ `process` - exists ([stdlib/process.md](docs/docs/stdlib/process.md))
     - ✅ `rand` - exists ([stdlib/rand.md](docs/docs/stdlib/rand.md))
     - ✅ `serial` - exists ([stdlib/serial.md](docs/docs/stdlib/serial.md))
     - ✅ `settings` - exists ([stdlib/settings.md](docs/docs/stdlib/settings.md))
     - ✅ `urlparse` - exists ([stdlib/urlparse.md](docs/docs/stdlib/urlparse.md))
     - ✅ `uuid` - exists ([stdlib/uuid.md](docs/docs/stdlib/uuid.md))

   - **Pages needing expansion**:
     - `std/encoding` - exists but could be more comprehensive
     - `std/crypto` - basic docs exist but missing some functions
     - Database modules - overview exists, individual DB pages may need detail
     - `std/process/expect` - may need dedicated section or page

   - **Missing documentation** (needs implementation verification):
     - `std/log` (QEP-004: Draft - not yet implemented)

3. **Missing Language Feature Documentation**
   - ❌ Decorators (QEP-003: Proposed - **NOT implemented yet**)
   - ⚠️ Traits - basic coverage but missing implementation examples
   - ⚠️ Context managers (with statement) - basic but needs more examples
   - ⚠️ Type annotations - partially documented
   - ⚠️ Inline if expressions (`value if condition else other`)
   - ⚠️ Elvis operator (`?:`) - QEP-019 implemented but not prominent in main docs
   - ⚠️ Bitwise operators - mentioned but not fully documented
   - ⚠️ Compound assignment operators - incomplete
   - ⚠️ Default parameters (QEP-033) - recently implemented, needs docs
   - ⚠️ Variadic parameters (QEP-034) - recently implemented (MVP), needs docs

4. **Incomplete Operator Documentation**
   - Bitwise operators: `&`, `|`, `^`, `~`, `<<`, `>>`
   - Logical operators: `and`, `or`, `not` (mentioned but no dedicated section)
   - Comparison chaining (if implemented)

5. **Missing Advanced Topics**
   - Module system details (search paths, overlays)
   - Error handling best practices
   - Performance considerations
   - Memory model (mutability, references)
   - Scope and variable lifetime

### Accuracy Issues

1. **Outdated Information**
   - Some examples reference old `Num` type (mostly fixed but verify)
   - Function signature changes may not be reflected everywhere
   - Type promotion rules need verification across all docs

2. **Inconsistent Method Documentation**
   - Some types document all methods, others only highlight a few
   - Return types not consistently documented
   - Parameter types not always specified

3. **Code Examples**
   - Some examples may not run as written
   - Missing expected output for many examples
   - Error handling examples are sparse

### Organization Issues

1. **Sidebar Structure**
   - Built-in types section incomplete (missing Bytes, BigInt, Uuid, Bool, Nil)
   - No clear separation between basic and advanced stdlib modules
   - Database modules could be grouped together
   - Encoding/compression modules could be grouped

2. **Page Structure Inconsistencies**
   - Type pages have different section orders
   - Method documentation format varies between pages
   - Some pages start with examples, others with overview

3. **Navigation**
   - No clear learning path for beginners vs. reference for experienced users
   - Cross-references between related topics are inconsistent
   - "See Also" sections are present on some pages but not others

### Consistency Issues

1. **Naming Conventions**
   - Mix of lowercase and Title case in headings
   - Type names: should consistently use `Int`, `Float`, `String`, `Array`, `Dict` (not `int`, `str`, etc.)
   - Method names: need consistent backtick usage

2. **Code Style**
   - Inconsistent indentation in examples (2 vs 4 spaces)
   - Variable naming conventions vary
   - Comment style inconsistent

3. **Terminology**
   - "dictionary" vs "dict" - pick one
   - "function" vs "method" - clarify distinction
   - "module" vs "package" - be consistent

4. **Example Format**
   - Some examples show REPL interaction (`>>`), others just code
   - Output format varies (some show `# Output:`, others use `puts()`)
   - Error examples format inconsistent

## Proposed Improvements

### Phase 1: Completeness (High Priority)

1. **Add Missing Type Pages to Sidebar**
   - ✅ Add existing `docs/types/bytes.md` to sidebar under "Built-in Types"

   - ❌ Create `docs/types/bigint.md` with:
     - BigInt literal syntax (`123n`)
     - Unlimited precision explanation
     - All arithmetic methods (from QEP-020)
     - Static methods: `new`, `from_int`, `from_bytes`
     - Global constants: ZERO, ONE, TWO, TEN
     - Use cases: cryptography, large numbers

   - ❌ Create `docs/types/bool.md` with:
     - Boolean literals: `true`, `false`
     - Truthiness rules (0, nil are falsy)
     - Logical operators
     - Comparison operations

   - ❌ Create `docs/types/nil.md` with:
     - Nil literal
     - Nil as singleton (ID 0)
     - Nil checking patterns
     - Elvis operator usage
     - Optional fields in types (`field: type?`)

2. **Add Existing Module Pages to Sidebar**

   **Quick wins** - These pages exist but aren't linked:
   - ✅ Add `compress` to sidebar
   - ✅ Add `database` to sidebar (overview exists)
   - ✅ Add `html_templates` to sidebar
   - ✅ Add `http` to sidebar
   - ✅ Add `process` to sidebar
   - ✅ Add `rand` to sidebar
   - ✅ Add `serial` to sidebar
   - ✅ Add `settings` to sidebar
   - ✅ Add `urlparse` to sidebar
   - ✅ Add `uuid` to sidebar

3. **Expand Existing Module Documentation**
   - ⚠️ Expand `docs/stdlib/encoding.md` to cover:
     - JSON (cross-reference existing page)
     - Base64 (b64)
     - Hex encoding
     - URL encoding (cross-reference urlparse)
     - CSV
     - Struct pack/unpack

   - ⚠️ Review and expand `docs/stdlib/database.md`:
     - Verify QEP-001 compliance coverage
     - Add connection string format examples
     - Common patterns and best practices
     - Error handling
     - Consider individual DB pages if needed:
       - `docs/stdlib/db/sqlite.md`
       - `docs/stdlib/db/postgres.md`
       - `docs/stdlib/db/mysql.md`

   - ⚠️ Expand `docs/stdlib/process.md` with:
     - `process.run()` - simple command execution
     - `process.spawn()` - advanced process control
     - `process.expect()` - interactive automation (QEP-022)
     - Examples for each use case

   - ❌ **DEFER**: `std/log` documentation (QEP-004 not yet implemented)
     - Wait for implementation before documenting

4. **Complete Language Documentation**

   - ❌ **DEFER**: `docs/language/decorators.md` (QEP-003: Proposed, **not implemented**)
     - Wait for implementation before documenting

   - ⚠️ Create or expand `docs/language/operators.md` with:
     - Arithmetic: `+`, `-`, `*`, `/`, `%`
     - Bitwise: `&`, `|`, `^`, `~`, `<<`, `>>`
     - Logical: `and`, `or`, `not`
     - Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
     - Elvis: `?:` (from QEP-019)
     - Assignment: `=`, `+=`, `-=`, `*=`, `/=`, `%=`
     - Precedence table

   - ⚠️ Add inline if to `docs/language/control-flow.md`:
     ```quest
     let result = value if condition else default
     ```

   - ⚠️ Add to `docs/language/functions.md`:
     - Default parameters (QEP-033 - recently implemented)
     - Variadic parameters `*args` (QEP-034 MVP - recently implemented)
     - `**kwargs` syntax structure (awaiting QEP-035)

### Phase 2: Accuracy (High Priority)

1. **Automated Example Testing**
   - ⚠️ Create test harness to validate code examples:
     ```bash
     # Extract code blocks from markdown
     # Run through Quest interpreter
     # Verify expected output matches
     ```
   - ⚠️ Add to CI/CD pipeline to catch regressions
   - ⚠️ Mark examples with expected behavior:
     - `<!-- expect: output -->` for working examples
     - `<!-- expect: error -->` for error demonstrations

2. **Verify All Code Examples Manually**
   - ⚠️ Run each example through Quest interpreter
   - ⚠️ Add expected output as comments
   - ⚠️ Fix any errors or outdated syntax (e.g., old `Num` type references)
   - ⚠️ Add error handling examples where appropriate

3. **Standardize Method Documentation**
   - ⚠️ Apply consistent format across all type pages:
     ```markdown
     ### method_name(param1, param2) → ReturnType

     Description of what the method does.

     **Parameters:**
     - `param1: Type` - description
     - `param2: Type` - description

     **Returns:** `ReturnType` - description

     **Example:**
     ```quest
     let result = obj.method_name(arg1, arg2)
     puts(result)  # Expected output
     ```
     ```

4. **Update Type Promotion Documentation**
   - ⚠️ Document all promotion rules in one place (likely [types/number.md](docs/docs/types/number.md))
   - ⚠️ Cross-reference from Float, Decimal docs
   - ⚠️ Include examples of each rule:
     - `Int + Int = Int`
     - `Int + Float = Float`
     - `Int + Decimal = Decimal`
     - `Float + Decimal = Decimal`

### Phase 3: Organization (Medium Priority)

1. **Restructure Sidebar** ([sidebars.ts](docs/sidebars.ts))

   **Proposed structure** (adds missing pages, reorganizes stdlib):
   ```typescript
   Built-in Types:
     - Int, Float, Decimal         # existing: types/number
     - String                       # existing: types/string
     - Bytes                        # ADD: types/bytes (exists, not linked)
     - Bool and Nil                 # CREATE: types/bool, types/nil
     - Array                        # existing: types/array
     - Dict                         # existing: types/dicts
     - BigInt                       # CREATE: types/bigint
     - Uuid                         # ADD: stdlib/uuid → move to types?

   Standard Library:
     - Overview                     # existing: stdlib/index

     Core Modules:
       - math                       # existing
       - str                        # existing
       - sys                        # existing
       - os                         # existing
       - time                       # existing
       - io                         # existing

     Encoding & Compression:
       - encoding (overview)        # existing
       - json                       # existing
       - urlparse                   # ADD (exists)
       - compress                   # ADD (exists)

     Data & Crypto:
       - hash                       # existing
       - crypto                     # existing
       - uuid                       # ADD (exists) - or move to types?
       - rand                       # ADD (exists)

     Database:
       - database (overview)        # ADD (exists)
       # Individual DB pages TBD

     Web & Network:
       - http                       # ADD (exists)
       - html_templates             # ADD (exists)
       - serial                     # ADD (exists)

     Development & Testing:
       - test                       # existing
       - regex                      # existing
       - settings                   # ADD (exists)
       # log - DEFER until QEP-004 implemented

     Process Control:
       - process                    # ADD (exists)
   ```

   **Note**: This organizes 24 stdlib modules (up from current 14) by category

2. **Add Getting Started Guide**
   - Create `docs/tutorial/` directory with:
     - `01-hello-world.md`
     - `02-variables-and-types.md`
     - `03-control-flow.md`
     - `04-functions.md`
     - `05-collections.md`
     - `06-modules.md`
     - `07-error-handling.md`

3. **Create Cookbook**
   - Create `docs/cookbook/` with common patterns:
     - File I/O
     - Database operations
     - HTTP requests
     - JSON processing
     - Testing
     - CLI tools

### Phase 4: Consistency (Medium Priority)

1. **Establish Style Guide**
   - Create `docs/STYLE_GUIDE.md` with:
     - Type name capitalization (Int, not int)
     - Code example format
     - Indentation (4 spaces)
     - Comment style
     - Output format
     - Heading capitalization

2. **Apply Style Guide**
   - Run through all documentation
   - Fix type name references
   - Standardize code examples
   - Consistent method documentation

3. **Add Cross-References**
   - Each type page should link to:
     - Related types
     - Relevant stdlib modules
     - Language features that use the type
   - Each module page should link to:
     - Types it works with
     - Related modules

## Implementation Plan

### Step 0: Audit ✅ (COMPLETED 2025-10-07)
- [x] Create comprehensive list of all missing pages
- [x] Identify which pages exist but aren't in sidebar
- [x] Document current organization
- [x] List consistency issues
- [x] Verify QEP implementation status

**Key findings:**
- 10 stdlib pages exist but aren't in sidebar (quick wins)
- Only 3 type pages need creation (BigInt, Bool, Nil)
- Bytes page exists, just needs linking
- QEP-003 (decorators) and QEP-004 (logging) not yet implemented

### Step 1: Quick Wins (1-2 hours)
- [ ] Add 10 existing stdlib pages to sidebar
- [ ] Add existing Bytes page to sidebar
- [ ] Reorganize sidebar into categories (Core, Encoding, Database, Web, etc.)

### Step 2: Style Guide (1 day)
- [ ] Create `docs/STYLE_GUIDE.md`
- [ ] Define type name capitalization (Int vs int)
- [ ] Define code example format
- [ ] Define method documentation template
- [ ] Get community feedback
- [ ] Finalize guidelines

### Step 3: Create Missing Type Pages (2-3 days)
- [ ] Create `types/bigint.md` (reference QEP-020)
- [ ] Create `types/bool.md`
- [ ] Create `types/nil.md`
- [ ] Add to sidebar

### Step 4: Language Feature Updates (2-3 days)
- [ ] Add default parameters to `language/functions.md` (QEP-033)
- [ ] Add variadic parameters to `language/functions.md` (QEP-034)
- [ ] Create/expand `language/operators.md` with all operators
- [ ] Add inline if to `language/control-flow.md`
- [ ] Expand Elvis operator coverage

### Step 5: Accuracy & Testing (1 week)
- [ ] Create automated test harness for code examples
- [ ] Run all examples through Quest interpreter
- [ ] Fix broken/outdated examples
- [ ] Add expected output to all examples
- [ ] Standardize method documentation format across all pages

### Step 6: Organization (3-4 days)
- [ ] Create tutorial series (`docs/tutorial/`)
- [ ] Create cookbook (`docs/cookbook/`)
- [ ] Add cross-references between related pages
- [ ] Add "See Also" sections

### Step 7: Polish (2-3 days)
- [ ] Apply style guide to all pages
- [ ] Verify all internal links work
- [ ] Update search index/configuration
- [ ] Add version indicators where appropriate

## Success Metrics

1. **Completeness**:
   - 100% of implemented features have documentation
   - 100% of sidebar items link to existing pages
   - All orphaned documentation pages are linked from sidebar

2. **Accuracy**:
   - All code examples run without errors
   - All code examples have expected output documented
   - Automated test harness passes for all examples

3. **Organization**:
   - Users can find information in ≤3 clicks from homepage
   - Stdlib organized into logical categories
   - Tutorial path exists for new users

4. **Consistency**:
   - All pages follow style guide
   - Method documentation uses standard format
   - Type names capitalized consistently

5. **Discoverability**:
   - All major features findable via search
   - Cross-references exist between related topics
   - "See Also" sections on all major pages

## References

**Implemented QEPs** (need documentation):
- QEP-019: Elvis operator (`?:`)
- QEP-020: BigInt support
- QEP-033: Default parameters
- QEP-034: Variadic parameters (MVP)
- QEP-037: Typed exceptions

**Proposed/Draft QEPs** (defer documentation):
- QEP-003: Function decorators (Proposed - not implemented)
- QEP-004: Logging module (Draft - not implemented)
- QEP-035: Named arguments (Draft - awaiting)

**Other references**:
- QEP-001: Database API standardization
- QEP-022: Process expect module
- Current documentation: `docs/docs/`
- Sidebar configuration: `docs/sidebars.ts`

## Notes

This is a living document. As new features are added to Quest, this QEP should be updated to track documentation needs.

**Priority order**:
1. **Quick wins** - Add existing pages to sidebar (Step 1)
2. **Recently implemented features** - QEP-033, QEP-034, QEP-037
3. **Missing fundamentals** - Bool, Nil, BigInt type pages
4. **Accuracy** - Fix broken examples, add automated testing
5. **Organization** - Tutorial path, cookbook, cross-references
6. **Future features** - Only document after implementation

**Guiding principles**:
- Document what exists, not what's planned
- Verify implementation status before writing docs
- Automate example testing to prevent rot
- Make quick wins first (maximum impact, minimum effort)
