# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## High-Level Architecture

This is a PowerDNS Docker Compose stack featuring a modern distributed DNS setup with:

- **PowerDNS Authoritative Server** (v4.9) with LMDB backend - Primary DNS server using Lightning Memory-Mapped Database instead of traditional SQL backends
- **LightningStream** - Real-time LMDB synchronization service that enables distributed PowerDNS deployments by syncing database changes to S3-compatible storage
- **MinIO** - S3-compatible object storage that serves as the central sync point for multiple PowerDNS instances
- **PowerDNS Admin** - Web-based management interface for DNS zone management
- **MinIO Client** - One-time setup container that creates required S3 buckets

Key architectural decisions:
- Uses LMDB backend (Lightning Memory-Mapped Database) instead of traditional SQL databases for better performance
- LightningStream enables horizontal scaling by syncing LMDB changes across multiple PowerDNS instances via S3 storage
- All services communicate over a dedicated Docker network (`powerdns-network`)
- Persistent volumes ensure data survives container restarts

## Common Commands

All commands use Docker Compose v2 syntax (per user preference).

### Stack Management
```bash
# Start the entire stack
docker compose up -d

# Start specific services only
docker compose up -d minio powerdns

# Stop all services
docker compose down

# Stop and remove all data (destructive)
docker compose down -v

# View service status
docker compose ps

# Restart a specific service
docker compose restart powerdns
```

### Development and Debugging
```bash
# View logs for all services
docker compose logs -f

# View logs for specific service
docker compose logs -f powerdns
docker compose logs -f lightningstream

# Execute commands inside containers
docker compose exec powerdns /bin/bash
docker compose exec powerdns pdnsutil list-all-zones

# Check LMDB sync status
docker compose logs lightningstream | tail -20

# Monitor resource usage
docker compose top
```

### DNS Testing and Management
```bash
# Test DNS resolution
dig @localhost example.com A
nslookup example.com localhost

# Access PowerDNS API (replace API key from .env)
curl -X GET http://localhost:8081/api/v1/servers/localhost/zones \
  -H "X-API-Key: your-super-secret-api-key-here"

# Create DNS zone via API
curl -X POST http://localhost:8081/api/v1/servers/localhost/zones \
  -H "X-API-Key: your-super-secret-api-key-here" \
  -H "Content-Type: application/json" \
  -d '{"name": "example.com.", "kind": "Native"}'
```

## Configuration Management

### Environment Variables
- Primary config: `.env` file (committed with default/example values)
- Local overrides: `.env.local` (gitignored for local development)
- Production: `.env.production` (gitignored for production secrets)

Key variables:
- `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` - MinIO admin credentials
- `PDNS_AUTH_API_KEY` - PowerDNS API authentication key

### Service Configuration Files
- `config/pdns.conf` - PowerDNS server configuration (LMDB backend, API settings)
- `config/lightningstream.yaml` - LightningStream sync configuration (S3 endpoint, intervals)

### Making Configuration Changes
1. Edit configuration files in `config/` directory
2. Update environment variables in `.env` or `.env.local`
3. Restart affected services: `docker compose restart <service-name>`

## Key Files and Customization

### Core Files
- `docker-compose.yml` - Main service orchestration definition
- `.env` - Environment variables and secrets
- `config/pdns.conf` - PowerDNS server configuration  
- `config/lightningstream.yaml` - Real-time sync configuration

### Multi-Instance Setup
For distributed deployments across multiple servers:
1. Change `sync.instance_id` in `config/lightningstream.yaml` for each instance
2. Ensure all instances point to the same MinIO S3 storage
3. LightningStream will automatically handle cross-instance synchronization

### Data Persistence and Bind Volumes
All persistent data is stored on the host filesystem using bind volumes for easy backup and management:

- `./data/minio/` - MinIO S3 storage data (mapped to `/data` in container)
- `./data/pdns-lmdb/` - PowerDNS LMDB database (mapped to `/var/lib/powerdns`, shared with LightningStream)
- `./data/pda-data/` - PowerDNS Admin SQLite database (mapped to `/data` in container)
- `./config/` - Configuration files (mounted read-only)

### Directory Structure
```
powerdns-docker/
├── data/                    # Persistent data (bind volumes)
│   ├── minio/              # MinIO S3 storage
│   ├── pdns-lmdb/          # PowerDNS LMDB database
│   └── pda-data/           # PowerDNS Admin database
├── backups/                # Backup archives
├── config/                 # Configuration files
├── scripts/                # Utility scripts
└── docker-compose.yml      # Main compose file
```

## Troubleshooting

### Service Health Checks
```bash
# Check all service status
docker compose ps

# View health check logs
docker compose logs minio | grep health

# Test MinIO connectivity
curl -f http://localhost:9000/minio/health/live
```

### Common Issues and Solutions

**DNS not resolving:**
```bash
# Check PowerDNS container logs
docker compose logs powerdns | tail -50

# Verify LMDB permissions and data
docker compose exec powerdns ls -la /var/lib/powerdns/

# Test PowerDNS API accessibility
curl -I http://localhost:8081
```

**LightningStream sync issues:**
```bash
# Check S3 connectivity and credentials
docker compose logs lightningstream | grep -i error

# Verify MinIO bucket exists
docker compose exec minio-client mc ls myminio/powerdns-sync
```

**PowerDNS Admin connection issues:**
```bash
# Ensure API key matches between services
grep PDNS_AUTH_API_KEY .env
docker compose logs powerdns-admin | grep -i api
```

### Data Backup and Recovery

**Create Backup:**
```bash
# Create a full backup (includes data, config, and compose file)
./scripts/backup.sh

# Manual backup using tar
tar -czf backups/manual_backup_$(date +"%Y%m%d_%H%M%S").tar.gz data/ config/ .env docker-compose.yml
```

**Restore from Backup:**
```bash
# List available backups
./scripts/restore.sh

# Restore specific backup
./scripts/restore.sh powerdns_backup_20240314_120000.tar.gz

# Manual restore
docker compose down
tar -xzf backups/powerdns_backup_YYYYMMDD_HHMMSS.tar.gz
docker compose up -d
```

**Data Recovery:**
```bash
# Reset all data and start fresh (destructive)
docker compose down
rm -rf data/
mkdir -p data/{minio,pdns-lmdb,pda-data}
docker compose up -d

# Backup individual LMDB database (while running)
docker compose exec powerdns cp /var/lib/powerdns/pdns.lmdb /var/lib/powerdns/pdns.lmdb.backup
```

## Development Best Practices

### Working with This Repository
- Always use Docker Compose v2 commands (`docker compose`, not `docker-compose`)
- Keep sensitive credentials in `.env.local` (gitignored) for local development
- Test DNS changes locally before deploying to production instances
- Monitor LightningStream logs when working with multi-instance setups

### Common Development Workflows
1. **Adding new DNS zones:** Use PowerDNS Admin web interface (http://localhost:9191) or API
2. **Testing configuration changes:** Restart specific services, don't rebuild entire stack unless necessary  
3. **Debugging sync issues:** Check LightningStream logs and MinIO console for S3 operations
4. **Performance testing:** Use `dig` and `nslookup` for DNS query testing
5. **Creating backups:** Run `./scripts/backup.sh` before major changes
6. **Migrating data:** Use backup/restore scripts to move between environments

### Backup Automation
For production environments, consider setting up automated backups:

```bash
# Add to crontab for daily backups at 2 AM
0 2 * * * cd /path/to/powerdns-docker && ./scripts/backup.sh >> logs/backup.log 2>&1

# Weekly backup with different retention
0 3 * * 0 cd /path/to/powerdns-docker && ./scripts/backup.sh && find backups/ -name "powerdns_backup_*.tar.gz" -mtime +30 -delete
```

**Backup Best Practices:**
- Stop services before backup for consistency: `docker compose down`
- Test restore procedures regularly
- Store backups on separate storage/server for disaster recovery
- Monitor backup script logs for failures
- Verify backup integrity periodically

### Security Considerations
- Change default credentials in `.env` before production deployment
- Use strong API keys (minimum 32 characters)
- Consider network-level security for production (firewall rules, VPN)
- Regularly backup MinIO data for disaster recovery

## Web Interfaces
- **PowerDNS Admin:** http://localhost:9191 (DNS management interface)
- **MinIO Console:** http://localhost:9001 (S3 storage management)
- **PowerDNS API:** http://localhost:8081 (REST API for DNS operations)

## Port Mapping
- `53/TCP,UDP` - DNS queries (PowerDNS)
- `8081` - PowerDNS API and web server  
- `9191` - PowerDNS Admin web interface
- `9000` - MinIO S3 API
- `9001` - MinIO management console