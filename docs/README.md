# Quest Documentation Deployment

This directory contains the Quest documentation generator and deployment configuration.

## Building the Documentation

Generate the static documentation site:

```bash
cd ..
./target/release/quest docs/build.q
```

This creates the static site in `docs/output/`.

## Local Development

Serve the documentation locally using Quest's built-in static file server:

```bash
# From project root
./target/release/quest serve docs/output --port 8080
```

Or use any static file server:

```bash
cd docs/output
python3 -m http.server 8080
```

Visit http://localhost:8080

## Docker Deployment

### Build the Docker Image

Build from the `docs` directory:

```bash
cd docs
docker build -t quest-docs:latest .
```

The multi-stage Dockerfile will:
1. Install Quest from crates.io (`cargo install vibequest`)
2. Run the documentation build script
3. Create a minimal nginx image with the static output (~30MB final image)

### Run the Container

```bash
docker run -d \
  --name quest-docs \
  -p 8080:80 \
  quest-docs:latest
```

Visit http://localhost:8080

### Stop the Container

```bash
docker stop quest-docs
docker rm quest-docs
```

## Docker Compose

Create a `docker-compose.yml` in the `docs` directory:

```yaml
version: '3.8'

services:
  docs:
    build: .
    image: quest-docs:latest
    container_name: quest-docs
    ports:
      - "8080:80"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 3s
      retries: 3
```

Then run:

```bash
docker-compose up -d
```

## Production Deployment

### Using nginx-alpine (recommended)

The Dockerfile uses the lightweight `nginx:alpine` base image which is:
- Only ~23MB in size
- Production-ready nginx web server
- Includes health checks
- Optimized for serving static files

### Environment Variables

No environment variables are required. The container serves static files from `/usr/share/nginx/html/`.

### Volume Mounts

If you want to update docs without rebuilding:

```bash
docker run -d \
  --name quest-docs \
  -p 8080:80 \
  -v $(pwd)/output:/usr/share/nginx/html:ro \
  nginx:alpine
```

### Custom nginx Configuration

Create `docs/nginx.conf`:

```nginx
server {
    listen 80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    # Enable gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Cache static assets
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # SPA fallback (if needed)
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

Uncomment the COPY line in the Dockerfile and rebuild.

## Cloud Deployment Examples

### Deploy to Fly.io

1. Install flyctl: https://fly.io/docs/hands-on/install-flyctl/

2. Create `fly.toml` in `docs/`:

```toml
app = "quest-docs"
primary_region = "sjc"

[build]
  dockerfile = "Dockerfile"

[http_service]
  internal_port = 80
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 256
```

3. Deploy:

```bash
cd docs
fly launch
fly deploy
```

### Deploy to Railway

1. Install Railway CLI: https://docs.railway.app/develop/cli

2. Deploy:

```bash
cd docs
railway init
railway up
```

### Deploy to Render

1. Connect your GitHub repo to Render
2. Create a new "Static Site" service
3. Set build command: `cd docs && docker build -t quest-docs .`
4. Set publish directory: `docs/output`

### Deploy to GitHub Pages

Generate the docs and push to `gh-pages` branch:

```bash
# Build docs
./target/release/quest docs/build.q

# Push to gh-pages branch
cd docs/output
git init
git checkout -b gh-pages
git add .
git commit -m "Deploy documentation"
git remote add origin <your-repo-url>
git push -f origin gh-pages
```

Enable GitHub Pages in repository settings, select `gh-pages` branch.

## Updating Documentation

1. Make changes to documentation source in `docs/docs/`
2. Rebuild: `./target/release/quest docs/build.q`
3. Rebuild Docker image: `cd docs && docker build -t quest-docs:latest .`
4. Restart container: `docker stop quest-docs && docker rm quest-docs && docker run -d --name quest-docs -p 8080:80 quest-docs:latest`

Or with Docker Compose:

```bash
./target/release/quest docs/build.q
cd docs
docker-compose up -d --build
```

## Automated Builds

Add to your CI/CD pipeline (e.g., GitHub Actions):

```yaml
name: Build and Deploy Docs

on:
  push:
    branches: [main]
    paths:
      - 'docs/docs/**'
      - 'docs/templates/**'
      - 'docs/public/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build Docker Image
        run: |
          cd docs
          docker build -t quest-docs:${{ github.sha }} .

      - name: Push to Registry
        run: |
          echo "${{ secrets.DOCKER_PASSWORD }}" | docker login -u "${{ secrets.DOCKER_USERNAME }}" --password-stdin
          docker tag quest-docs:${{ github.sha }} your-registry/quest-docs:latest
          docker push your-registry/quest-docs:latest
```

## Structure

```
docs/
├── docs/           # Documentation source (Markdown)
├── templates/      # HTML templates (Tera)
├── public/         # Static assets (CSS, JS)
├── output/         # Generated site (git-ignored)
├── build.q         # Documentation builder script
├── sidebar.q       # Sidebar generation script
├── Dockerfile      # Docker build configuration
└── README.md       # This file
```
