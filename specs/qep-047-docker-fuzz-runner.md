# QEP-047: Parallel VM Fuzz Runner

**Number**: 047
**Status**: Draft
**Author**: Steven
**Created**: 2025-10-08

## Motivation

Fuzz testing Quest requires running many isolated sessions to find edge cases and bugs:
- Manual execution doesn't scale
- Need parallelization for overnight runs
- Want VM isolation to prevent contamination between runs

We need infrastructure to run N fuzz sessions using M concurrent workers in isolated Docker containers.

## Proposal

Run N total fuzz sessions using M concurrent workers (M < N), each running a Claude Code agent in an isolated Docker container.

**Hard Requirements:**
1. Execute Claude Code agent with fuzzing prompt in each container
2. Run with limited concurrent workers (default: 3, configurable up to 8-16)
3. Support high total run counts (e.g., 100-500 sessions) processed in batches
4. VM isolation (Docker containers)
5. Prevent git operations and limit network access

**Example:** 100 total runs with 3 workers means containers 1-3 run, then 4-6, then 7-9, etc.

## Implementation

### Dockerfile (`docker/fuzz-runner/Dockerfile`)

```dockerfile
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl git build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Rust and build Quest
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /quest
COPY . .
RUN cargo build --release

# Install Claude Code CLI (if available, otherwise use API directly)
RUN pip install --no-cache-dir claude-code || true

WORKDIR /workspace
CMD ["/bin/bash"]
```

### Python Orchestrator (`docker/fuzz-runner/run.py`)

```python
#!/usr/bin/env python3
"""
Run fuzzing agents in parallel Docker containers.

Usage:
    python run.py --parallel 8 --runs 100
"""

import asyncio
import os
import sys
import time
from pathlib import Path
import docker

PROJECT_ROOT = Path(__file__).parent.parent.parent
FUZZ_DIR = PROJECT_ROOT / "fuzz" / "runs"
IMAGE_NAME = "quest-fuzzer"

class FuzzRunner:
    def __init__(self, workers=3, total=100, dry_run=False):
        self.workers = workers  # Max concurrent containers
        self.total = total      # Total runs to complete
        self.dry_run = dry_run  # Print commands without executing
        self.client = docker.from_env() if not dry_run else None
        self.api_key = os.environ.get("ANTHROPIC_API_KEY")

        if not self.api_key and not dry_run:
            print("ERROR: Set ANTHROPIC_API_KEY")
            sys.exit(1)

    async def run_agent(self, n):
        """Run fuzzing agent in container with access to test services"""
        session_dir = FUZZ_DIR / f"{n:03d}"
        session_dir.mkdir(parents=True, exist_ok=True)

        print(f"[{n:03d}] Starting...")

        if self.dry_run:
            print(f"[{n:03d}] DRY-RUN: Would run container with:")
            print(f"         - Session dir: {session_dir}")
            print(f"         - Network: quest2_default")
            print(f"         - Timeout: 900s")
            print(f"[{n:03d}] DRY-RUN: Complete")
            return

        try:
            # Connect to existing docker-compose network to access test services
            # Assumes docker-compose up is already running
            try:
                network = self.client.networks.get("quest2_default")
            except docker.errors.NotFound:
                print(f"[{n:03d}] Warning: docker-compose network not found, creating isolated network")
                network = self.client.networks.create(
                    f"fuzz-{n:03d}",
                    driver="bridge",
                    internal=False
                )

            # Run container with fuzz prompt from fuzz/prompt.md
            prompt_file = PROJECT_ROOT / "fuzz" / "prompt.md"
            start_time = time.time()

            try:
                container = self.client.containers.run(
                    IMAGE_NAME,
                    command=["/bin/bash", "-c", "cd /quest && claude-code < /quest/fuzz/prompt.md"],
                    volumes={
                        str(session_dir.absolute()): {'bind': '/workspace/fuzz', 'mode': 'rw'},
                        str(PROJECT_ROOT.absolute()): {'bind': '/quest', 'mode': 'ro'},
                        str(prompt_file.absolute()): {'bind': '/fuzz-prompt.md', 'mode': 'ro'}
                    },
                    environment={
                        'ANTHROPIC_API_KEY': self.api_key,
                        'GIT_TERMINAL_PROMPT': '0',  # Disable git prompts
                        # Connection strings for test services
                        'POSTGRES_HOST': 'quest-postgres-test',
                        'POSTGRES_PORT': '5432',
                        'POSTGRES_USER': 'quest',
                        'POSTGRES_PASSWORD': 'quest_password',
                        'POSTGRES_DB': 'quest_test',
                        'MYSQL_HOST': 'quest-mysql-test',
                        'MYSQL_PORT': '3306',
                        'MYSQL_USER': 'quest',
                        'MYSQL_PASSWORD': 'quest_password',
                        'MYSQL_DB': 'quest_test',
                        'HTTPBIN_URL': 'http://quest-httpbin-test:8080',
                    },
                    mem_limit='2g',
                    cpu_quota=100000,  # 1 CPU
                    read_only=True,  # Read-only filesystem
                    tmpfs={'/tmp': 'size=100m,noexec'},  # Writable tmp, no exec
                    security_opt=['no-new-privileges'],
                    cap_drop=['ALL'],  # Drop all capabilities
                    network=network.name,
                    dns=['1.1.1.1'],  # Use Cloudflare DNS
                    remove=True,
                    detach=False,
                    timeout=900  # 15 minute timeout
                )

                # Mark success
                (session_dir / "SUCCESS").write_text(f"Completed in {time.time() - start_time:.1f}s\n")
                print(f"[{n:03d}] ✓ Done ({time.time() - start_time:.1f}s)")

            except docker.errors.ContainerError as e:
                # Container exited with non-zero status
                (session_dir / "ERROR").write_text(f"Exit code: {e.exit_status}\n\nLogs:\n{e.stderr.decode()}\n")
                print(f"[{n:03d}] ✗ Failed: Container error (exit {e.exit_status})")
            except asyncio.TimeoutError:
                # Container timed out
                (session_dir / "TIMEOUT").write_text(f"Timed out after 900s\n")
                print(f"[{n:03d}] ✗ Failed: Timeout after 900s")

        except Exception as e:
            # Unexpected error (network, Docker daemon, etc.)
            (session_dir / "ERROR").write_text(f"Unexpected error: {e}\n")
            print(f"[{n:03d}] ✗ Failed: {e}")

    async def run(self):
        """Run campaign with limited workers using semaphore for efficient parallelism"""
        if not self.dry_run:
            print(f"Building image...")
            self.client.images.build(path=str(PROJECT_ROOT), tag=IMAGE_NAME)

        print(f"Running {self.total} fuzz sessions with {self.workers} workers...")

        # Use semaphore for true worker pool (no idle slots)
        semaphore = asyncio.Semaphore(self.workers)
        completed = 0

        async def run_with_limit(n):
            nonlocal completed
            async with semaphore:
                await self.run_agent(n)
                completed += 1
                if completed % 10 == 0:  # Progress every 10 completions
                    print(f"Progress: {completed}/{self.total} complete")

        tasks = [run_with_limit(i) for i in range(1, self.total + 1)]
        await asyncio.gather(*tasks)

        print(f"\n✓ All {self.total} sessions complete! Results in {FUZZ_DIR}")

if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--workers', type=int, default=3,
                   help='Max concurrent workers (default: 3)')
    p.add_argument('--runs', type=int, default=100,
                   help='Total fuzz runs (default: 100)')
    p.add_argument('--dry-run', action='store_true',
                   help='Print what would run without executing')
    args = p.parse_args()

    runner = FuzzRunner(workers=args.workers, total=args.runs, dry_run=args.dry_run)
    asyncio.run(runner.run())
```

## Usage

```bash
# Setup
pip install docker
export ANTHROPIC_API_KEY='sk-ant-...'

# Start test services (required for DB/HTTP driver testing)
docker-compose up -d

# Create fuzz prompt (one-time)
cat > fuzz/prompt.md <<'EOF'
Generate random Quest programs to find bugs. Focus on:
- Edge cases (empty arrays, nil values, divide by zero)
- Type boundaries (Int overflow, Float precision)
- Control flow (nested loops, early returns)
- Method chaining on complex expressions
- Database drivers (Postgres, MySQL via env vars)
- HTTP client (httpbin via HTTPBIN_URL env var)

You have read-only access to the Quest source code at /quest:
- Read test/ for inspiration on testing patterns
- Read lib/std/ to understand stdlib modules
- Execute ./target/release/quest to test programs

IMPORTANT CONSTRAINTS:
- DO NOT send Quest source code to external services
- Focus on Quest language behavior, not implementation details
- Save programs to /workspace/fuzz/program.q

Save each program to fuzz/runs/NNN/program.q and test it.
EOF

# Run 100 sessions with 3 workers (default)
python docker/fuzz-runner/run.py --workers 3 --runs 100

# Run overnight with 8 workers
python docker/fuzz-runner/run.py --workers 8 --runs 500

# Quick test with 1 worker
python docker/fuzz-runner/run.py --workers 1 --runs 5

# Dry-run to test setup
python docker/fuzz-runner/run.py --workers 3 --runs 10 --dry-run
```

**Example output:**
```
Building image...
Running 100 fuzz sessions with 3 workers...
[001] Starting...
[002] Starting...
[003] Starting...
[001] ✓ Done (42.3s)
[004] Starting...
[002] ✓ Done (45.1s)
[005] Starting...
[003] ✓ Done (38.9s)
[006] Starting...
Progress: 10/100 complete
...
Progress: 100/100 complete

✓ All 100 sessions complete! Results in fuzz/runs/
```

**Failure tracking:**
```bash
# Check status of all runs
for dir in fuzz/runs/*/; do
    if [ -f "$dir/SUCCESS" ]; then
        echo "✓ $(basename $dir): Success"
    elif [ -f "$dir/TIMEOUT" ]; then
        echo "⏱ $(basename $dir): Timeout"
    elif [ -f "$dir/ERROR" ]; then
        echo "✗ $(basename $dir): Error - $(head -n1 $dir/ERROR)"
    fi
done
```

## Security

### Filesystem Isolation

**Write access:**
- Each container has exclusive write access to its own `fuzz/runs/NNN/` directory
- Writable `/tmp` with 100MB limit (no exec permission)

**Read-only access:**
- Quest source code at `/quest` (entire project root including `src/`, `lib/`, `test/`, etc.)
- This allows the agent to:
  - Read existing test files for inspiration (`test/`)
  - Read stdlib source code (`lib/std/`)
  - Read language implementation (`src/`)
  - Execute the Quest binary (`./target/release/quest`)

**No access:**
- `.git/` directory (prevents examining commit history, though git binary is available)
- SSH keys, credentials, or home directory
- Other containers' `fuzz/runs/` directories
- Host filesystem outside project root

**Security implications:**
- Agent can read all project code (intended - helps generate contextual test cases)
- Agent cannot modify Quest source or tests (read-only mount)
- Agent cannot push to git (no `.git/` access + `GIT_TERMINAL_PROMPT=0`)
- Agent could read sensitive data if present in project (e.g., `.env` files, hardcoded secrets)

### Network Restrictions
- Containers join docker-compose network to access test services:
  - `quest-postgres-test` (PostgreSQL on port 5432)
  - `quest-mysql-test` (MySQL on port 3306)
  - `quest-httpbin-test` (HTTP testing on port 8080)
- All external HTTP/HTTPS traffic routed through filtering proxy
- Proxy allows only Claude API domains:
  - `api.anthropic.com` (Claude API endpoints)
  - `claude.ai` (WebFetch safeguards)
  - `statsig.anthropic.com` (Telemetry and metrics)
- Direct access allowed to Docker internal networks (test services)
- Block all other outbound traffic beyond Docker network
- Prevents data exfiltration beyond required test services

### Resource Limits
- 2GB RAM per container
- CPU throttling to prevent exhaustion
- 15-minute timeout per agent

### Permissions
- No git operations allowed inside containers
- Read-only filesystem except for `/workspace/fuzz`
- API key passed as env var (not mounted file)

## Notes

1. **Test Services**: Requires `docker-compose up -d` before running to provide DB/HTTP test targets
2. **Network Discovery**: Automatically joins `quest2_default` network to access test services (falls back to isolated network if not found)
3. **Fuzz Prompt**: The prompt is stored in `fuzz/prompt.md` (read-only mount) so each container runs identical instructions
4. **Claude Code CLI**: If `claude-code` CLI doesn't exist, modify container command to invoke API directly
5. **Worker Pool**: Uses `asyncio.Semaphore` for efficient parallelism (no idle worker slots)
6. **Failure Tracking**: Each run creates `SUCCESS`, `TIMEOUT`, or `ERROR` marker files
7. **Session IDs**: Orchestrator creates `fuzz/runs/001/`, `002/`, etc.

## Known Limitations

1. **Network Isolation**: Use the Squid proxy approach for macOS compatibility and robust domain-based filtering. The iptables approach is Linux-only and requires periodic IP updates as CDNs rotate addresses.

2. **Git Access**: Containers have git binary installed and Quest source mounted (read-only). While this prevents pushes to the mounted repository, the agent could theoretically clone external repositories. Consider removing git from the container image if this is a concern.

3. **No Resume Support**: If the orchestrator crashes mid-run, you must restart from scratch. Consider adding a `--resume` flag that skips sessions with existing SUCCESS/ERROR/TIMEOUT markers.

4. **Sensitive Data Exposure**: Agents can read all files in the project root (including `.env`, config files, test credentials). The fuzz prompt should instruct agents NOT to exfiltrate data, but this is a trust boundary. For paranoid security, exclude sensitive files from the mount or use a clean checkout.

## Best Practices

1. **Clean Environment**: Consider fuzzing from a clean git checkout without `.env` files or credentials
2. **Fuzz Prompt Guidelines**: Include instructions in `fuzz/prompt.md` to:
   - NOT send project code snippets to external services
   - Focus on Quest language features, not implementation details
   - Avoid reading sensitive configuration files
3. **Monitor Costs**: Each container makes Claude API calls - set budget alerts
4. **Database Isolation**: The test databases (`quest_test`) should contain only synthetic data

## Network Whitelist Setup (Optional)

To restrict containers to only Claude API + test services, configure iptables on the host:

```bash
#!/bin/bash
# docker/fuzz-runner/setup-firewall.sh
# Configure network whitelist for Claude Code containers

# Resolve Claude domains to IPs (run this to get current IPs)
echo "Resolving Claude domains..."
API_IPS=$(dig +short api.anthropic.com | grep -E '^[0-9]+\.')
CLAUDE_IPS=$(dig +short claude.ai | grep -E '^[0-9]+\.')
STATSIG_IPS=$(dig +short statsig.anthropic.com | grep -E '^[0-9]+\.')

echo "api.anthropic.com: $API_IPS"
echo "claude.ai: $CLAUDE_IPS"
echo "statsig.anthropic.com: $STATSIG_IPS"

# Create custom chain for Docker fuzz traffic
sudo iptables -N DOCKER-FUZZ 2>/dev/null || sudo iptables -F DOCKER-FUZZ

# Allow test services (internal Docker network)
sudo iptables -A DOCKER-FUZZ -d 172.16.0.0/12 -j ACCEPT  # Docker default ranges

# Allow Claude API endpoints (api.anthropic.com)
for ip in $API_IPS; do
    sudo iptables -A DOCKER-FUZZ -d $ip -j ACCEPT
done

# Allow Claude.ai (WebFetch safeguards)
for ip in $CLAUDE_IPS; do
    sudo iptables -A DOCKER-FUZZ -d $ip -j ACCEPT
done

# Allow Statsig (telemetry)
for ip in $STATSIG_IPS; do
    sudo iptables -A DOCKER-FUZZ -d $ip -j ACCEPT
done

# Allow DNS resolution
sudo iptables -A DOCKER-FUZZ -p udp --dport 53 -j ACCEPT
sudo iptables -A DOCKER-FUZZ -p tcp --dport 53 -j ACCEPT

# Allow HTTPS to any IP (since domains resolve dynamically)
# Alternative: Use IP ranges from above
# sudo iptables -A DOCKER-FUZZ -p tcp --dport 443 -j ACCEPT

# Block everything else
sudo iptables -A DOCKER-FUZZ -j DROP

# Apply to Docker containers on fuzz networks (adjust subnet if needed)
sudo iptables -I DOCKER-USER -s 172.18.0.0/16 -j DOCKER-FUZZ

echo "✓ Firewall rules configured"
echo "To persist (Ubuntu): sudo iptables-save > /etc/iptables/rules.v4"
```

**Usage:**
```bash
# Run once before starting fuzz campaign
sudo bash docker/fuzz-runner/setup-firewall.sh

# Verify rules
sudo iptables -L DOCKER-FUZZ -n -v

# Remove rules
sudo iptables -D DOCKER-USER -s 172.18.0.0/16 -j DOCKER-FUZZ
sudo iptables -F DOCKER-FUZZ
sudo iptables -X DOCKER-FUZZ
```

**Notes:**
- Domain IPs can change - re-run script periodically or use DNS-based filtering
- macOS Docker Desktop: iptables rules reset on restart (re-run after reboot)

## Network Filtering Proxy

Use Squid proxy for domain-based filtering (works on macOS/Linux).

### Proxy Configuration (`docker/fuzz-runner/squid.conf`)

```conf
# Squid proxy config for Quest fuzzing containers
# Allows only Claude API domains + denies everything else

# Listen on all interfaces
http_port 3128

# Define allowed domains
acl claude_domains dstdomain .anthropic.com
acl claude_domains dstdomain .claude.ai

# SSL ports
acl SSL_ports port 443
acl CONNECT method CONNECT

# Allow CONNECT only to HTTPS and allowed domains
http_access deny CONNECT !SSL_ports
http_access allow CONNECT claude_domains

# Allow HTTP requests to Claude domains
http_access allow claude_domains

# Deny everything else
http_access deny all

# Don't cache anything (agents generate unique requests)
cache deny all

# Logging
access_log stdio:/dev/stdout
cache_log /dev/null
```

### Proxy Dockerfile (`docker/fuzz-runner/Dockerfile.proxy`)

```dockerfile
FROM ubuntu/squid:latest

# Copy Squid config
COPY squid.conf /etc/squid/squid.conf

# Expose proxy port
EXPOSE 3128

CMD ["squid", "-N", "-d", "1"]
```

### Update docker-compose.yml

Add proxy service to your docker-compose.yml:

```yaml
services:
  # Existing test services...
  quest-postgres-test:
    image: postgres:15
    # ...

  quest-mysql-test:
    image: mysql:8
    # ...

  quest-httpbin-test:
    image: kennethreitz/httpbin
    # ...

  # Add filtering proxy
  quest-proxy:
    build:
      context: docker/fuzz-runner
      dockerfile: Dockerfile.proxy
    container_name: quest-proxy
    networks:
      - default
    ports:
      - "3128:3128"
    restart: unless-stopped
```

### Update Python Orchestrator

Configure containers to use the proxy:

```python
# In run_agent() method, add to environment dict:
environment={
    'ANTHROPIC_API_KEY': self.api_key,
    'GIT_TERMINAL_PROMPT': '0',

    # Proxy configuration
    'HTTP_PROXY': 'http://quest-proxy:3128',
    'HTTPS_PROXY': 'http://quest-proxy:3128',
    'NO_PROXY': 'localhost,127.0.0.1,quest-postgres-test,quest-mysql-test,quest-httpbin-test',

    # Test service connection strings
    'POSTGRES_HOST': 'quest-postgres-test',
    # ... rest of env vars
}
```

### Usage

```bash
# Start test services + proxy
docker-compose up -d

# Verify proxy is running
curl -x http://localhost:3128 https://api.anthropic.com  # Should work
curl -x http://localhost:3128 https://google.com         # Should fail

# Run fuzzing (proxy configured automatically)
python docker/fuzz-runner/run.py --workers 3 --runs 100
```

**Benefits:**
- Works on macOS (no iptables dependency)
- Domain-based filtering (handles CDN IP changes)
- Transparent to containers (standard HTTP_PROXY env vars)
- Direct access to Docker networks via NO_PROXY (test services bypass proxy)
- Lightweight (~20MB container)

**Notes:**
- Squid logs all blocked requests to stdout for debugging
- `NO_PROXY` allows direct connections to test services (no proxy overhead)
- SSL inspection not enabled (trusts CONNECT requests to allowed domains)

## Alternative: Shell Script

If Python is too heavy:

```bash
#!/bin/bash
# docker/fuzz-runner/run.sh

WORKERS=${1:-3}  # Max concurrent containers
TOTAL=${2:-100}  # Total runs

docker build -t quest-fuzzer .

run_fuzz() {
    n=$(printf "%03d" $1)
    mkdir -p "fuzz/runs/$n"

    echo "[$n] Starting..."
    docker run --rm \
        -e ANTHROPIC_API_KEY \
        -e GIT_TERMINAL_PROMPT=0 \
        -v "$(pwd)/fuzz/runs/$n:/workspace/fuzz:rw" \
        -v "$(pwd):/quest:ro" \
        --memory 2g \
        --cpus 1 \
        --read-only \
        --tmpfs /tmp:size=100m,noexec \
        --security-opt no-new-privileges \
        --cap-drop ALL \
        quest-fuzzer \
        /bin/bash -c "cd /quest && timeout 900 claude-code < /quest/fuzz/prompt.md"

    echo "[$n] Done"
}

export -f run_fuzz
export ANTHROPIC_API_KEY

# Run with limited parallelism
seq 1 $TOTAL | xargs -P $WORKERS -I {} bash -c 'run_fuzz {}'

echo "✓ All $TOTAL sessions complete"
```

Usage:
```bash
./docker/fuzz-runner/run.sh 3 100  # 3 workers, 100 runs
./docker/fuzz-runner/run.sh 8 500  # 8 workers, 500 runs
```
