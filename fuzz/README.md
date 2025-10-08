# Quest Fuzz Testing

Automated fuzz testing system for discovering bugs and language improvements.

## Directory Structure

```
fuzz/
├── runs/               # Individual fuzz test sessions
│   ├── 001/           # Session 001
│   │   ├── program.q  # Generated test program
│   │   ├── bugs.md    # Bugs discovered
│   │   └── improve.md # Improvement suggestions
│   └── NNN/           # Additional sessions...
├── reports/           # Consolidated analysis reports
│   └── YYYY-MM-DD-HH:MM:SS_report.md
├── history.txt        # Chronological log of all sessions
└── log.sh             # Helper script for logging sessions
```

## Commands

### `/fuzz` - Run Fuzz Test
Generates and runs a new fuzz test session:
- Creates `fuzz/runs/NNN/` directory
- Generates test program targeting specific language features
- Executes program and captures results
- Documents bugs and improvements
- Updates history log

### `/fuzz-collect` - Generate Analysis Report
Analyzes all fuzz sessions and generates prioritized report:
- Categorizes bugs by severity (Critical/High/Medium/Low)
- Prioritizes improvements (High/Medium/Low)
- Groups issues by category (Parser, Type System, etc.)
- Identifies duplicate/related issues
- Saves timestamped report to `fuzz/reports/`

## Usage

```bash
# Run a fuzz test session
/fuzz

# Run focused test on specific feature
/fuzz "test decorator system with varargs"

# Generate consolidated report
/fuzz-collect
```

## Maintenance

Sessions in `fuzz/runs/` can be purged periodically to save space. History and reports are preserved.
