# PowerDNS with LightningStream Docker Compose

A modern PowerDNS Authoritative Server setup using LightningStream for distributed DNS with S3-compatible storage sync.

## Architecture

This setup includes:

- **PowerDNS Authoritative Server** (v4.9) with LMDB backend
- **LightningStream** for real-time LMDB synchronization
- **MinIO** as S3-compatible object storage
- **PowerDNS Admin** web interface for DNS management

## Features

- 🚀 **Modern LMDB Backend** - No SQL database required
- 🔄 **Real-time Sync** - LightningStream syncs changes across instances
- 📦 **S3 Compatible** - Uses MinIO for distributed storage
- 🌐 **Web Management** - PowerDNS Admin interface
- 🔧 **Docker Compose v2** - Easy deployment and management

## Quick Start

1. **Clone and setup**:
   ```bash
   cd /home/nusrath/powerdns-docker
   ```

2. **Configure environment variables**:
   ```bash
   cp .env .env.local
   # Edit .env.local with your settings
   ```

3. **Start the stack**:
   ```bash
   docker compose up -d
   ```

4. **Verify services**:
   ```bash
   docker compose ps
   ```

## Services and Ports

| Service | Port | Description |
|---------|------|-------------|
| PowerDNS | 53/UDP, 53/TCP | DNS queries |
| PowerDNS API | 8081 | REST API |
| PowerDNS Admin | 9191 | Web interface |
| MinIO API | 9000 | S3 API |
| MinIO Console | 9001 | Web interface |

## Configuration

### Environment Variables

Edit `.env` file to customize:

- `MINIO_ROOT_USER` - MinIO admin username
- `MINIO_ROOT_PASSWORD` - MinIO admin password  
- `PDNS_AUTH_API_KEY` - PowerDNS API key

### PowerDNS Configuration

The PowerDNS configuration is in `config/pdns.conf`:
- Uses LMDB backend
- API enabled for management
- Web server for statistics

### LightningStream Configuration

Configuration in `config/lightningstream.yaml`:
- Syncs every 10 seconds
- Connects to MinIO S3 storage
- Instance ID for multi-instance setups

## Usage

### Access Web Interfaces

- **PowerDNS Admin**: http://localhost:9191
- **MinIO Console**: http://localhost:9001 (admin/password from .env)

### DNS Management via API

```bash
# List zones
curl -X GET \
  http://localhost:8081/api/v1/servers/localhost/zones \
  -H "X-API-Key: your-super-secret-api-key-here"

# Create a zone
curl -X POST \
  http://localhost:8081/api/v1/servers/localhost/zones \
  -H "X-API-Key: your-super-secret-api-key-here" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "example.com.",
    "kind": "Native"
  }'
```

### Testing DNS Resolution

```bash
# Test DNS resolution
dig @localhost example.com A

# Test with specific nameserver
nslookup example.com localhost
```

## Multi-Instance Setup

For distributed DNS with multiple PowerDNS instances:

1. **Deploy multiple instances** with different `instance_id` in LightningStream config
2. **Share MinIO storage** - all instances use the same S3 bucket
3. **Automatic sync** - Changes propagate within seconds via LightningStream

## Monitoring

### Health Checks

```bash
# Check service health
docker compose ps

# View logs
docker compose logs -f powerdns
docker compose logs -f lightningstream
```

### MinIO Storage

- Check S3 bucket contents via MinIO console
- Monitor sync status in LightningStream logs

## Troubleshooting

### Common Issues

1. **DNS not resolving**:
   - Check if PowerDNS is running: `docker compose ps`
   - Verify LMDB permissions: `docker compose logs powerdns`

2. **LightningStream not syncing**:
   - Check MinIO connectivity: `docker compose logs lightningstream`
   - Verify S3 credentials in logs

3. **PowerDNS Admin connection issues**:
   - Verify API key matches between services
   - Check PowerDNS API accessibility: `curl http://localhost:8081`

### Debugging Commands

```bash
# Enter PowerDNS container
docker compose exec powerdns /bin/bash

# View LMDB contents
docker compose exec powerdns pdnsutil list-all-zones

# Check LightningStream status
docker compose logs lightningstream | tail -20
```

## File Structure

```
powerdns-docker/
├── docker-compose.yml          # Main compose file
├── .env                        # Environment variables
├── .gitignore                  # Git ignore rules  
├── README.md                   # This file
├── config/
│   ├── pdns.conf              # PowerDNS configuration
│   └── lightningstream.yaml   # LightningStream configuration
└── scripts/                   # Helper scripts
```

## Security Notes

- Change default passwords in `.env`
- Use strong API keys
- Consider network security for production
- Regularly backup MinIO data

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is provided as-is for educational and development purposes.