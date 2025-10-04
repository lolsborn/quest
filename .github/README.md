# GitHub Actions CI/CD

This directory contains the continuous integration and deployment workflows for Quest.

## Workflows

### 🧪 Test Suite (`test.yml`)

**Triggers**: Push to `main`/`develop`, Pull Requests
**Duration**: ~3-5 minutes

Runs the complete Quest test suite with all dependencies:
- **PostgreSQL 17** (port 6432)
- **MySQL 9.1** (port 6603)
- **httpbin** (port 6123)

**Steps**:
1. Checkout code
2. Install Rust toolchain (stable)
3. Cache dependencies (cargo registry, git, target)
4. Build Quest in release mode
5. Install Quest binary
6. Wait for all services to be healthy
7. Run full test suite (`./scripts/qtest`)
8. Upload test results (on failure)

**Environment Variables**:
- `QUEST_POSTGRES_PORT=6432`
- `QUEST_MYSQL_PORT=6603`
- `QUEST_HTTPBIN_PORT=6123`

### ⚡ Quick Check (`check.yml`)

**Triggers**: Push to `main`/`develop`, Pull Requests to `main`
**Duration**: ~1-2 minutes

Fast validation before running full test suite:
- Code formatting (`cargo fmt`)
- Linting (`cargo clippy`)
- Debug build
- Rust unit tests (`cargo test`)

## Service Health Checks

All services include health checks to ensure they're ready before tests run:

**PostgreSQL**:
```bash
pg_isready -h localhost -p 6432 -U quest
```

**MySQL**:
```bash
mysqladmin ping -h localhost -P 6603 -u root -proot_password
```

**httpbin**:
```bash
wget --quiet --tries=1 --spider http://localhost:8080/status/200
```

## Caching Strategy

Three-level caching for faster builds:
1. **Cargo Registry** - Downloaded crates
2. **Cargo Git** - Git dependencies
3. **Target Directory** - Compiled artifacts

Cache keys are based on `Cargo.lock` hash.

## Local Testing

To test the CI setup locally:

```bash
# Start services
docker-compose up -d

# Run the same checks as CI
cargo fmt -- --check
cargo clippy --all-targets --all-features -- -D warnings
cargo build --release
cargo install --path .
./scripts/qtest
```

## Debugging Failed Builds

1. Check the "Wait for services" step - services may not be ready
2. Review test output in the "Run test suite" step
3. Download "test-results" artifact for detailed logs
4. Run tests locally with `docker-compose up -d && ./scripts/qtest`

## Adding New Tests

When adding tests that require new services:
1. Add service to `docker-compose.yml`
2. Add service to `test.yml` workflow services section
3. Add health check to "Wait for services" step
4. Update this README

## Status Badges

Add to your README.md:

```markdown
![Test Suite](https://github.com/YOUR_USERNAME/quest/actions/workflows/test.yml/badge.svg)
![Quick Check](https://github.com/YOUR_USERNAME/quest/actions/workflows/check.yml/badge.svg)
```
