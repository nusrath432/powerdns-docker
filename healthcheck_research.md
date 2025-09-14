# Health Check and Labels Research for PowerDNS Stack

## Current Issues Identified

### 🔴 **Critical Issues:**
1. **PowerDNS Auth**: Using `exit 0` - doesn't actually test DNS functionality
2. **PowerDNS Recursor**: Using `exit 0` - doesn't test recursive resolution
3. **Missing Labels**: No container labels for identification, versioning, or metadata

### 🟡 **Minor Issues:**
1. **LightningStream**: Health check might be correct but needs verification
2. **MinIO**: Health check looks correct but should verify endpoint
3. **PowerDNS Admin**: Basic HTTP check might be insufficient

## Official Documentation Research

### PowerDNS Authoritative Server
**Official Docker Hub**: `powerdns/pdns-auth-50`
- **Proper Health Check**: Test DNS resolution on port 53
- **Recommended**: `dig @localhost SOA . +time=1 +tries=1`
- **Alternative**: Test API endpoint if webserver enabled
- **Port**: 53 (DNS) or 8081 (API if enabled)

### PowerDNS Recursor  
**Official Docker Hub**: `powerdns/pdns-recursor-54`
- **Proper Health Check**: Test recursive resolution
- **Recommended**: `dig @localhost google.com +time=1 +tries=1`
- **Alternative**: `rec_control ping` if available
- **Port**: 53 (DNS) or 8082 (web server if enabled)

### MinIO
**Official Docker Hub**: `minio/minio`
- **Current Check**: `curl -f http://localhost:9000/minio/health/ready` ✅ CORRECT
- **Alternative**: `/minio/health/live` (less strict)
- **Official Recommendation**: `/minio/health/ready` is preferred

### LightningStream
**Official Docker Hub**: `powerdns/lightningstream`
- **Current Check**: `wget http://localhost:8080/health` ✅ LIKELY CORRECT
- **Port**: 8080 (health endpoint)
- **Note**: Need to verify if health endpoint is actually exposed

### PowerDNS Admin
**Docker Hub**: `ngoduykhanh/powerdns-admin`
- **Current Check**: Basic HTTP check ⚠️ BASIC
- **Better Check**: Test actual login page or API endpoint
- **Port**: 80 (HTTP)

## Recommended Container Labels

Based on Docker best practices and PowerDNS ecosystem:

```yaml
labels:
  - "maintainer=your-email@domain.com"
  - "version=${IMAGE_TAG}"
  - "service.name=service-name"
  - "service.type=dns|storage|sync|admin"
  - "com.powerdns.stack=true"
  - "com.docker.compose.project=powerdns"
```

## Improved Health Checks

### PowerDNS Auth (Authoritative)
```yaml
healthcheck:
  test: ["CMD-SHELL", "dig @localhost SOA . +time=1 +tries=1 || exit 1"]
  interval: 10s
  timeout: 5s
  retries: 3
  start_period: 30s
```

### PowerDNS Recursor
```yaml
healthcheck:
  test: ["CMD-SHELL", "dig @localhost google.com +time=1 +tries=1 || exit 1"]
  interval: 10s
  timeout: 5s
  retries: 3
  start_period: 30s
```

### MinIO (Current is good)
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/ready"]
  interval: 30s
  timeout: 20s
  retries: 3
  start_period: 30s
```

### LightningStream
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 10s
  timeout: 5s
  retries: 3
  start_period: 30s
```

### PowerDNS Admin
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost/login"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

## Dependency Considerations

### Service Dependencies Should Be:
1. **MinIO** → No dependencies (base service)
2. **MinIO Client** → Depends on MinIO (healthy)
3. **PowerDNS Auth** → Depends on MinIO (healthy) - for LMDB sync
4. **LightningStream** → Depends on MinIO (healthy) AND PowerDNS Auth (started)
5. **PowerDNS Recursor** → Independent (no dependencies needed)
6. **PowerDNS Admin** → Depends on PowerDNS Auth (started)

## Additional Improvements Needed

### 1. Proper Labels
Add comprehensive labels for:
- Service identification
- Version tracking  
- Maintainer information
- Stack grouping

### 2. Health Check Tools
Ensure required tools are available:
- `dig` for DNS health checks
- `curl` for HTTP health checks
- Consider `drill` as `dig` alternative

### 3. Proper Timeouts
Adjust timeouts based on service type:
- DNS services: Short timeouts (5s)
- Web services: Medium timeouts (10s)
- Storage services: Longer timeouts (20s)

### 4. Start Periods
Adjust start periods based on service startup time:
- PowerDNS: 30s
- MinIO: 30s  
- PowerDNS Admin: 60s (Python app takes longer)
- LightningStream: 30s

## Next Steps
1. Update docker-compose.yml with proper health checks
2. Add comprehensive labels to all services
3. Test health checks in development environment
4. Verify all required tools are available in containers
5. Document any custom health check requirements