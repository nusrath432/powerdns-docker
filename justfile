# Load environment variables from .env
set dotenv-load

# Default recipe → help
default: help

# Show all available recipes
help:
    @echo ""
    @echo "🏗️  Environment Setup:"
    @echo "  just init                  # Initialize environment (directories, permissions, secrets)"
    @echo "  just setup                 # Complete setup: init + pull + up"
    @echo "  just check-deps            # Check system dependencies"
    @echo "  just fix-permissions       # Fix directory permissions"
    @echo "  just health                # Check service health status"
    @echo ""
    @echo "🐳 Docker Stack Management:"
    @echo "  just up                    # Start the stack in detached mode"
    @echo "  just build                 # Build and start the stack"
    @echo "  just down                  # Stop containers (keep volumes)"
    @echo "  just reset                 # Stop and remove containers + volumes"
    @echo "  just logs                  # View logs for all services"
    @echo "  just logs-service X        # View logs for service X"
    @echo "  just restart X             # Restart service X"
    @echo "  just pull                  # Pull latest images"
    @echo "  just exec [service]        # Exec shell into a container (default: powerdns-auth)"
    @echo "  just ps                    # Show container status"
    @echo ""
    @echo "🔐 DNSSEC Management:"
    @echo "  just dnssec-secure ZONE    # Enable DNSSEC for a zone"
    @echo "  just dnssec-disable ZONE   # Disable DNSSEC for a zone"
    @echo "  just dnssec-status ZONE    # Show DNSSEC status for a zone"
    @echo "  just dnssec-keys ZONE      # List DNSSEC keys for a zone"
    @echo "  just dnssec-ds ZONE        # Show DS record for parent zone"
    @echo "  just dnssec-validate ZONE  # Validate DNSSEC signatures"
    @echo "  just dnssec-test ZONE      # Test DNSSEC via recursor"
    @echo "  just dnssec-zones          # List all zones with DNSSEC status"
    @echo ""
    @echo "🌐 Zone Management:"
    @echo "  just create-zone ZONE      # Create a new zone"
    @echo "  just setup-org-zones       # Setup site.sa and cloud.site.sa zones"
    @echo "  just list-zones            # List all zones"
    @echo "  just add-record ZONE NAME TYPE VALUE # Add DNS record"
    @echo "  just show-zone ZONE        # Show zone contents"
    @echo ""
    @echo "🌐 DNS Testing:"
    @echo "  just dig ZONE [TYPE]       # Query via PowerDNS Auth (port 53)"
    @echo "  just dig-rec ZONE [TYPE]   # Query via PowerDNS Recursor (port 5353)"
    @echo "  just dig-dnssec ZONE       # Query with DNSSEC validation"
    @echo ""
    @echo "🔧 Troubleshooting:"
    @echo "  just debug                 # Show debug information"
    @echo "  just test-stack            # Run comprehensive stack tests"
    @echo "  just test-dns ZONE         # Test DNS functionality for zone"
    @echo ""

# Environment Setup Commands

# Initialize the environment
init:
    @echo "🏗️  Initializing PowerDNS Enterprise Stack..."
    @echo "📁 Creating directories..."
    mkdir -p ../data/minio ../data/lmdb ../data/pda ../data/pdns-config
    mkdir -p secrets
    @echo "🔐 Setting up secrets..."
    @just _create-secrets
    @echo "🔧 Fixing permissions..."
    @just fix-permissions
    @echo "✅ Environment initialized successfully!"
    @echo "💡 Run 'just setup' to complete the installation."

# Complete setup process
setup: init
    @echo "🚀 Starting complete PowerDNS setup..."
    @just pull
    @just up
    @echo "⏳ Waiting for services to start..."
    sleep 30
    @just health
    @echo "🎉 PowerDNS Enterprise Stack is ready!"
    @echo "🌐 Access PowerDNS Admin: http://localhost:9191"
    @echo "🗂️  Access MinIO Console: http://localhost:9001"

# Check system dependencies
check-deps:
    @echo "🔍 Checking system dependencies..."
    @echo "Docker version:"
    @docker --version
    @echo "Docker Compose version:"
    @docker compose version
    @echo "Available ports:"
    @if netstat -tuln | grep -q :1053; then echo "❌ Port 1053 is in use"; else echo "✅ Port 1053 is available"; fi
    @if netstat -tuln | grep -q :5353; then echo "❌ Port 5353 is in use"; else echo "✅ Port 5353 is available"; fi
    @if netstat -tuln | grep -q :9191; then echo "❌ Port 9191 is in use"; else echo "✅ Port 9191 is available"; fi
    @if netstat -tuln | grep -q :9000; then echo "❌ Port 9000 is in use"; else echo "✅ Port 9000 is available"; fi
    @echo "Disk space:"
    @df -h ../data

# Fix directory permissions
fix-permissions:
    @echo "🔧 Fixing directory permissions..."
    sudo chown -R $(id -u):$(id -g) ../data/
    chmod 755 ../data/minio ../data/lmdb ../data/pda
    @echo "🔐 Setting MinIO permissions..."
    sudo chown -R 1001:1001 ../data/minio || echo "MinIO user (1001) permissions set"
    @echo "📁 Setting LMDB permissions..."
    sudo chown -R 953:953 ../data/lmdb || echo "PowerDNS user (953) permissions set"
    @echo "✅ Permissions fixed"

# Check service health
health:
    @echo "🏥 Checking service health..."
    @echo "Container status:"
    @docker compose ps
    @echo ""
    @echo "Service health checks:"
    @if docker compose exec -T powerdns-auth pdns_control ping >/dev/null 2>&1; then echo "✅ PowerDNS Auth: Healthy"; else echo "❌ PowerDNS Auth: Unhealthy"; fi
    @if docker compose exec -T powerdns-recursor rec_control ping >/dev/null 2>&1; then echo "✅ PowerDNS Recursor: Healthy"; else echo "❌ PowerDNS Recursor: Unhealthy"; fi
    @if curl -sf http://localhost:9000/minio/health/ready >/dev/null 2>&1; then echo "✅ MinIO: Healthy"; else echo "❌ MinIO: Unhealthy"; fi
    @if curl -sf http://localhost:9191 >/dev/null 2>&1; then echo "✅ PowerDNS Admin: Healthy"; else echo "❌ PowerDNS Admin: Unhealthy"; fi

# Create secrets files (internal helper)
_create-secrets:
    @echo "admin" > secrets/minio_root_user
    @echo "SecureMinIOPassword2024SiteSA" > secrets/minio_root_password
    @echo "powerdns-enterprise-api-key-2024-site-sa-secure" > secrets/pdns_api_key
    chmod 600 secrets/*

# Troubleshooting Commands

# Show debug information
debug:
    @echo "🐛 PowerDNS Stack Debug Information"
    @echo "===================================="
    @echo ""
    @echo "📊 System Information:"
    @echo "Date: $(date)"
    @echo "User: $(whoami)"
    @echo "Working Directory: $(pwd)"
    @echo ""
    @echo "🐳 Docker Information:"
    @docker --version
    @docker compose version
    @echo ""
    @echo "📁 Directory Structure:"
    @ls -la ../data/
    @echo ""
    @echo "🔐 Secrets Status:"
    @ls -la secrets/
    @echo ""
    @echo "📋 Container Status:"
    @docker compose ps
    @echo ""
    @echo "🌐 Port Usage:"
    @netstat -tuln | grep -E ':(1053|5353|8081|9000|9001|9191)'
    @echo ""
    @echo "💾 Disk Usage:"
    @du -sh ../data/*

# Run comprehensive stack tests
test-stack:
    @echo "🧪 Running comprehensive PowerDNS stack tests..."
    @echo ""
    @echo "1️⃣  Testing service connectivity..."
    @just health
    @echo ""
    @echo "2️⃣  Testing DNS resolution..."
    @if just dig google.com A >/dev/null 2>&1; then echo "✅ PowerDNS Auth responding"; else echo "❌ PowerDNS Auth not responding"; fi
    @if just dig-rec google.com A >/dev/null 2>&1; then echo "✅ PowerDNS Recursor responding"; else echo "❌ PowerDNS Recursor not responding"; fi
    @echo ""
    @echo "3️⃣  Testing API connectivity..."
    @if docker compose exec -T powerdns-auth curl -sf http://localhost:8081/api/v1/servers >/dev/null 2>&1; then echo "✅ PowerDNS API responding"; else echo "❌ PowerDNS API not responding"; fi
    @echo ""
    @echo "4️⃣  Testing storage..."
    @if curl -sf http://localhost:9000/minio/health/ready >/dev/null 2>&1; then echo "✅ MinIO storage healthy"; else echo "❌ MinIO storage unhealthy"; fi
    @echo ""
    @echo "✅ Stack testing complete!"

# Test DNS functionality for a specific zone
test-dns zone:
    @echo "🧪 Testing DNS functionality for zone: {{zone}}"
    @echo ""
    @echo "📋 Testing authoritative server..."
    @just dig {{zone}} SOA
    @echo ""
    @echo "📋 Testing recursive server..."
    @just dig-rec {{zone}} SOA
    @echo ""
    @echo "🔐 Testing DNSSEC (if enabled)..."
    @just dig-dnssec {{zone}} SOA
    @echo ""
    @echo "✅ DNS testing complete for {{zone}}"

up:
    docker compose --env-file .env --env-file .env.secrets up -d

build:
    docker compose --env-file .env --env-file .env.secrets up -d --build

down:
    docker compose --env-file .env --env-file .env.secrets down

reset:
    docker compose --env-file .env --env-file .env.secrets down -v

logs:
    docker compose --env-file .env --env-file .env.secrets logs -f

logs-service service:
    docker compose --env-file .env --env-file .env.secrets logs -f {{service}}

restart service:
    docker compose --env-file .env --env-file .env.secrets restart {{service}}

pull:
    docker compose --env-file .env --env-file .env.secrets pull

exec service="powerdns-auth":
    docker compose --env-file .env --env-file .env.secrets exec -it {{service}} /bin/sh

ps:
    docker compose --env-file .env --env-file .env.secrets ps

# Zone Management Commands

# Create a new DNS zone
create-zone zone:
    @echo "🌐 Creating DNS zone: {{zone}}"
    docker compose --env-file .env --env-file .env.secrets exec powerdns-auth pdnsutil create-zone {{zone}}
    @echo "✅ Zone {{zone}} created successfully"
    @echo "💡 Add DNS records using: just add-record {{zone}} name type value"

# Setup organizational zones (site.sa and cloud.site.sa)
setup-org-zones:
    @echo "🏢 Setting up organizational zones..."
    @echo "🌐 Creating site.sa zone..."
    @just create-zone site.sa
    @just add-record site.sa "@" A "185.199.108.153"
    @just add-record site.sa "www" CNAME "site.sa."
    @just add-record site.sa "ns1" A "185.199.108.153"
    @just add-record site.sa "ns2" A "185.199.109.153"
    @echo ""
    @echo "🌐 Creating cloud.site.sa zone..."
    @just create-zone cloud.site.sa
    @just add-record cloud.site.sa "@" A "185.199.108.153"
    @just add-record cloud.site.sa "www" CNAME "cloud.site.sa."
    @just add-record cloud.site.sa "ns1" A "185.199.108.153"
    @just add-record cloud.site.sa "ns2" A "185.199.109.153"
    @echo ""
    @echo "✅ Organizational zones created successfully!"
    @echo "🔐 Enable DNSSEC with: just dnssec-secure site.sa"
    @echo "🔐 Enable DNSSEC with: just dnssec-secure cloud.site.sa"

# List all DNS zones
list-zones:
    @echo "📋 All DNS zones:"
    docker compose --env-file .env --env-file .env.secrets exec powerdns-auth pdnsutil list-zones

# Add a DNS record to a zone
add-record zone name type value:
    @echo "📝 Adding {{type}} record: {{name}}.{{zone}} -> {{value}}"
    docker compose --env-file .env --env-file .env.secrets exec powerdns-auth pdnsutil add-record {{zone}} {{name}} {{type}} {{value}}
    @echo "✅ Record added successfully"

# Show zone contents
show-zone zone:
    @echo "🗺️  Zone contents for: {{zone}}"
    docker compose --env-file .env --env-file .env.secrets exec powerdns-auth pdnsutil list-zone {{zone}}

# DNSSEC Management Commands

# Enable DNSSEC for a zone
dnssec-secure zone:
    @echo "🔐 Enabling DNSSEC for zone: {{zone}}"
    docker compose --env-file .env --env-file .env.secrets exec powerdns-auth pdnsutil secure-zone {{zone}}
    @echo "✅ DNSSEC enabled for {{zone}}"
    @echo "📋 Don't forget to submit the DS record to your registrar:"
    @just dnssec-ds {{zone}}

# Disable DNSSEC for a zone
dnssec-disable zone:
    @echo "⚠️  Disabling DNSSEC for zone: {{zone}}"
    @echo "This will remove all DNSSEC keys and signatures!"
    docker compose --env-file .env --env-file .env.secrets exec powerdns-auth pdnsutil disable-dnssec {{zone}}
    @echo "✅ DNSSEC disabled for {{zone}}"

# Show DNSSEC status for a zone
dnssec-status zone:
    @echo "📊 DNSSEC status for zone: {{zone}}"
    docker compose --env-file .env --env-file .env.secrets exec powerdns-auth pdnsutil show-zone {{zone}}

# List DNSSEC keys for a zone
dnssec-keys zone:
    @echo "🔑 DNSSEC keys for zone: {{zone}}"
    docker compose --env-file .env --env-file .env.secrets exec powerdns-auth pdnsutil list-keys {{zone}}

# Show DS record for parent zone submission
dnssec-ds zone:
    @echo "📋 DS record for {{zone}} (submit to parent zone/registrar):"
    @echo "" 
    docker compose --env-file .env --env-file .env.secrets exec powerdns-auth pdnsutil show-zone {{zone}} | grep "^DS"
    @echo ""
    @echo "Submit this DS record to your domain registrar or parent zone."

# Validate DNSSEC signatures for a zone
dnssec-validate zone:
    @echo "✅ Validating DNSSEC for zone: {{zone}}"
    @echo "Checking zone consistency..."
    docker compose --env-file .env --env-file .env.secrets exec powerdns-auth pdnsutil check-zone {{zone}}
    @echo "Testing DNSSEC signatures..."
    @just dig-dnssec {{zone}}

# Test DNSSEC validation via recursor
dnssec-test zone:
    @echo "🧪 Testing DNSSEC validation via recursor for: {{zone}}"
    @echo "Testing via PowerDNS Recursor (port 5353)..."
    docker compose --env-file .env --env-file .env.secrets exec powerdns-recursor drill -D {{zone}} SOA
    @echo "DNSSEC validation status:"
    @just dig-rec {{zone}} SOA

# List all zones with DNSSEC status
dnssec-zones:
    @echo "📋 All zones with DNSSEC status:"
    @docker compose --env-file .env --env-file .env.secrets exec powerdns-auth pdnsutil list-zones | while read zone; do \
        if docker compose exec powerdns-auth pdnsutil list-keys "$$zone" 2>/dev/null | grep -q "KSK\|ZSK"; then \
            echo "  ✅ $$zone (DNSSEC enabled)"; \
        else \
            echo "  ❌ $$zone (DNSSEC disabled)"; \
        fi; \
    done

# DNS Testing Commands

# Query DNS via PowerDNS Auth (port 53)
dig zone type="A":
    @echo "🔍 Querying {{zone}} {{type}} via PowerDNS Auth (port 53):"
    docker compose --env-file .env --env-file .env.secrets exec powerdns-auth dig @localhost {{zone}} {{type}}

# Query DNS via PowerDNS Recursor (port 5353)  
dig-rec zone type="A":
    @echo "🔍 Querying {{zone}} {{type}} via PowerDNS Recursor (port 5353):"
    docker compose --env-file .env --env-file .env.secrets exec powerdns-recursor dig @localhost -p 5353 {{zone}} {{type}}

# Query DNS with DNSSEC validation
dig-dnssec zone type="SOA":
    @echo "🔐 Querying {{zone}} {{type}} with DNSSEC signatures:"
    docker compose --env-file .env --env-file .env.secrets exec powerdns-auth dig +dnssec +cd @localhost {{zone}} {{type}}
