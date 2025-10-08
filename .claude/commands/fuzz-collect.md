---
allowed-tools:
  - ReadFile(fuzz/**/*)
  - WriteFile(fuzz/reports/**)
  - WriteFile(/tmp/**)
  - Bash(ls:*)
  - Bash(cat:*)
  - Bash(mkdir:*)
description: Collect and prioritize all fuzz test findings
---
## Your Task

Analyze all fuzz test sessions in `fuzz/runs/` and compile a comprehensive prioritized report of bugs and improvements.

### Steps:

1. **Discover all fuzz sessions**
   - List directories in `fuzz/runs/` (format: `NNN/`)
   - Read `bugs.md` and `improve.md` from each session
   - Read `fuzz/history.txt` for session context

2. **Categorize and prioritize findings**

   **Bug Priority Levels:**
   - **Critical**: Crashes, data corruption, security issues
   - **High**: Broken features, incorrect behavior, missing functionality
   - **Medium**: API inconsistencies, confusing errors, parser issues
   - **Low**: Minor UX issues, documentation gaps

   **Improvement Priority Levels:**
   - **High**: Missing core features affecting usability
   - **Medium**: Nice-to-have features, API improvements
   - **Low**: Documentation, examples, minor enhancements

3. **Group by category**
   - Parser/Syntax issues
   - Type system
   - Decorator system
   - Exception system
   - Function parameters (defaults, varargs, kwargs)
   - Standard library
   - Error messages/UX
   - Documentation

4. **Identify patterns**
   - Recurring issues across multiple sessions
   - Related bugs that share root causes
   - Features partially implemented vs completely missing

5. **Generate report** with sections:
   ```markdown
   # Quest Fuzz Test Findings Report
   Generated: [timestamp]
   Sessions analyzed: [list]

   ## Executive Summary
   - Total bugs: X (Critical: X, High: X, Medium: X, Low: X)
   - Total improvements: X (High: X, Medium: X, Low: X)
   - Key themes: [brief overview]

   ## Critical Issues
   [Bugs that need immediate attention]

   ## High Priority Bugs
   [Grouped by category with session references]

   ## Medium Priority Bugs
   [Grouped by category]

   ## Low Priority Bugs
   [Quick list]

   ## High Priority Improvements
   [Feature requests by category]

   ## Medium Priority Improvements
   [Nice-to-have features]

   ## Low Priority Improvements
   [Documentation and minor enhancements]

   ## Recommendations
   [Suggested action items in priority order]
   ```

6. **Cross-reference duplicates**
   - Mark duplicate issues with "(also in session XXX)"
   - Consolidate related issues into single items

7. **Save report**
   - Write to `fuzz/reports/YYYY-MM-DD-HH:MM:SS_report.md` (use actual timestamp)
   - Display summary to user

### Important Guidelines

- Be objective and technical
- Include session numbers for traceability
- Quote relevant code snippets for clarity
- Suggest concrete solutions where possible
- Note which features are partially vs completely missing
- Highlight patterns that suggest architectural issues
