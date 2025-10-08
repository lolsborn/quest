---
allowed-tools: 
  - Bash(git status:*)
  - Bash(git log:*)
  - Bash(./target/debug/quest:*)
  - Bash(./target/release/quest:*)
  - Bash(rg:*)
  - Bash(grep:*)
  - Bash(ls:*)
  - Bash(cargo build:*)
  - Bash(fuzz/log.sh:*)
  - WriteFile(fuzz/**)       # Allow creating new files in fuzz/
  - WriteFile(/tmp/**)       # Allow creating new files in /tmp/
  - Edit(fuzz/**)            # Allow editing existing files in fuzz/
  - ReadFile(./**)           # Allow reading all project files
  - Bash(mkdir:*)            # To create fuzz session directories
  - Bash(cat:*)              # To read log files
  - Bash(tail:*)             # To monitor logs
description: Fuzz Testing
---
## Your Task

1. **Find the next session number** by checking existing directories in `fuzz/runs/`
2. **Determine focus area**:
   - If user provided feature description, focus on those features
   - Otherwise, choose a random program type from this list:
   - Data structures (arrays, dicts, nested structures)
   - Control flow (if/elif/else, while, for..in, match)
   - Functions (regular, lambdas, closures, default params, varargs, kwargs)
   - Type system (user types, traits, methods, inheritance)
   - Exception handling (try/catch/ensure, typed exceptions)
   - String operations (interpolation, concatenation, methods)
   - Number operations (Int, Float, BigInt, Decimal arithmetic)
   - Standard library (choose random module from std/*)
   - Advanced features (decorators, context managers, module system)
   - Edge cases (deeply nested expressions, large literals, boundary conditions)

3. **Generate a valid Quest program** (200-500 lines) that:
   - Tests the chosen feature comprehensively
   - Includes edge cases and boundary conditions
   - Uses `std/test` for structured testing, OR plain assertions/output checks (fuzz tests don't need to integrate with test suite)
   - Is syntactically and semantically correct
   - Includes comments explaining what it tests

4. **Create session directory** `fuzz/runs/NNN/` with:
   - `program.q` - The generated test program
   - `bugs.md` - Document any bugs found (if program crashes, produces wrong output, or behaves unexpectedly)
   - `improve.md` - Suggest language improvements or missing features discovered

5. **Run the program** with `./target/release/quest fuzz/runs/NNN/program.q`
   - Capture output and any errors
   - Analyze behavior for correctness

6. **Update history** - Use the logging script:
   ```bash
   ./fuzz/log.sh "NNN" "Brief description of what was tested" "fuzz/runs/NNN/program.q"
   ```
   This ensures consistent timestamp formatting.

7. **Report findings** - Summarize:
   - What feature was tested
   - Whether program ran successfully
   - Any bugs discovered (with details in bugs.md)
   - Any improvements suggested (with details in improve.md)

## Important Rules

- Generate VALID Quest syntax (study CLAUDE.md and existing test files)
- Test real language features, not made-up syntax
- Be creative with edge cases and combinations
- Don't skip running the program
- Document issues clearly with reproduction steps
- Make programs substantial enough to stress-test the interpreter
