#!/bin/bash

# PowerDNS Docker Compose Test Script
# This script verifies the entire PowerDNS setup is working correctly

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
API_KEY="your-super-secret-api-key-here"
TEST_ZONE="test.local."
TEST_RECORD="www.test.local."
TEST_IP="192.168.1.100"
DNS_PORT="5353"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}✓${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo_error() {
    echo -e "${RED}✗${NC} $1"
}

echo_test() {
    echo -e "${BLUE}🧪${NC} $1"
}

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo_test "Testing: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo_info "$test_name: PASSED"
        ((TESTS_PASSED++))
        return 0
    else
        echo_error "$test_name: FAILED"
        ((TESTS_FAILED++))
        return 1
    fi
}

run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    
    echo_test "Testing: $test_name"
    
    local output
    output=$(eval "$test_command" 2>&1)
    
    if [[ "$output" =~ $expected_pattern ]]; then
        echo_info "$test_name: PASSED"
        ((TESTS_PASSED++))
        return 0
    else
        echo_error "$test_name: FAILED"
        echo "Expected pattern: $expected_pattern"
        echo "Actual output: $output"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "🚀 Starting PowerDNS Docker Compose Test Suite"
echo "================================================"

# Change to project directory
cd "$PROJECT_DIR"

# Test 1: Check if services are running
echo_test "Testing: Service Status"
if docker compose ps | grep -q "Up\|healthy"; then
    echo_info "Docker Compose services are running"
    ((TESTS_PASSED++))
else
    echo_error "Docker Compose services are not running properly"
    echo "Current status:"
    docker compose ps
    ((TESTS_FAILED++))
fi

# Test 2: MinIO Health Check
run_test "MinIO Health Check" "curl -f -s http://localhost:9000/minio/health/live"

# Test 3: MinIO Console Access
run_test "MinIO Console Access" "curl -I -s http://localhost:9001 | grep -q '200 OK'"

# Test 4: PowerDNS API Access
run_test "PowerDNS API Access" "curl -s -H 'X-API-Key: $API_KEY' http://localhost:8081/api/v1/servers | grep -q 'localhost'"

# Test 5: PowerDNS Admin Access
run_test "PowerDNS Admin Access" "curl -I -s http://localhost:9191 | grep -q '302 FOUND'"

# Test 6: Data Directory Existence
echo_test "Testing: Data Directory Structure"
if [[ -d "data/minio" && -d "data/pdns-lmdb" && -d "data/pda-data" ]]; then
    echo_info "Data directories exist"
    ((TESTS_PASSED++))
else
    echo_error "Data directories missing"
    ((TESTS_FAILED++))
fi

# Test 7: LMDB Files Exist
echo_test "Testing: LMDB Database Files"
if ls data/pdns-lmdb/*.lmdb >/dev/null 2>&1; then
    echo_info "LMDB database files exist"
    ((TESTS_PASSED++))
else
    echo_error "LMDB database files not found"
    ((TESTS_FAILED++))
fi

# Test 8: DNS Zone Creation
echo_test "Testing: DNS Zone Management"
zone_result=$(curl -s -X POST \
  http://localhost:8081/api/v1/servers/localhost/zones \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$TEST_ZONE\", \"kind\": \"Native\"}" 2>/dev/null)

if [[ "$zone_result" =~ "test.local" ]] || [[ "$zone_result" =~ "already exists" ]]; then
    echo_info "DNS Zone Management: PASSED"
    ((TESTS_PASSED++))
else
    echo_error "DNS Zone Management: FAILED"
    echo "Zone creation output: $zone_result"
    ((TESTS_FAILED++))
fi

# Test 9: DNS Record Creation
echo_test "Testing: DNS Record Management"
record_result=$(curl -s -X PATCH \
  "http://localhost:8081/api/v1/servers/localhost/zones/${TEST_ZONE%.*}" \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"rrsets\": [
      {
        \"name\": \"$TEST_RECORD\",
        \"type\": \"A\",
        \"changetype\": \"REPLACE\",
        \"ttl\": 300,
        \"records\": [
          {
            \"content\": \"$TEST_IP\",
            \"disabled\": false
          }
        ]
      }
    ]
  }" 2>&1)

if [[ -z "$record_result" ]] || [[ "$record_result" =~ "success" ]]; then
    echo_info "DNS Record Management: PASSED"
    ((TESTS_PASSED++))
else
    echo_error "DNS Record Management: FAILED"
    echo "Record creation output: $record_result"
    ((TESTS_FAILED++))
fi

# Test 10: DNS Resolution
echo_test "Testing: DNS Resolution"
sleep 2  # Give DNS a moment to propagate
dns_result=$(dig @localhost -p $DNS_PORT "$TEST_RECORD" A +short 2>/dev/null | grep -v '^;' | head -1)

if [[ "$dns_result" == "$TEST_IP" ]]; then
    echo_info "DNS Resolution: PASSED ($TEST_RECORD -> $dns_result)"
    ((TESTS_PASSED++))
else
    echo_error "DNS Resolution: FAILED"
    echo "Expected: $TEST_IP, Got: $dns_result"
    ((TESTS_FAILED++))
fi

# Test 11: Backup Functionality
echo_test "Testing: Backup Creation"
if ./scripts/backup.sh >/dev/null 2>&1; then
    echo_info "Backup Creation: PASSED"
    ((TESTS_PASSED++))
else
    echo_error "Backup Creation: FAILED"
    ((TESTS_FAILED++))
fi

# Test 12: Backup Files Exist
echo_test "Testing: Backup Files"
if ls backups/powerdns_backup_*.tar.gz >/dev/null 2>&1; then
    echo_info "Backup Files: PASSED"
    backup_count=$(ls backups/powerdns_backup_*.tar.gz | wc -l)
    echo "  Found $backup_count backup file(s)"
    ((TESTS_PASSED++))
else
    echo_error "Backup Files: FAILED"
    ((TESTS_FAILED++))
fi

# Test 13: Configuration Files
echo_test "Testing: Configuration Files"
config_files=("config/pdns.conf" "config/lightningstream.yaml" ".env" "docker-compose.yml")
config_ok=true
for file in "${config_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo_error "Missing configuration file: $file"
        config_ok=false
    fi
done

if $config_ok; then
    echo_info "Configuration Files: PASSED"
    ((TESTS_PASSED++))
else
    echo_error "Configuration Files: FAILED"
    ((TESTS_FAILED++))
fi

# Test 14: Port Accessibility
echo_test "Testing: Port Accessibility"
ports_ok=true
expected_ports=("8081" "9000" "9001" "9191" "5353")
for port in "${expected_ports[@]}"; do
    if ! nc -z localhost "$port" 2>/dev/null; then
        echo_error "Port $port is not accessible"
        ports_ok=false
    fi
done

if $ports_ok; then
    echo_info "Port Accessibility: PASSED"
    ((TESTS_PASSED++))
else
    echo_error "Port Accessibility: FAILED"
    ((TESTS_FAILED++))
fi

# Test Results Summary
echo ""
echo "================================================"
echo "🏁 Test Suite Complete"
echo "================================================"
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo_info "🎉 All tests passed! Your PowerDNS setup is working correctly."
    echo ""
    echo "🌐 Access your services:"
    echo "  PowerDNS API:    http://localhost:8081"
    echo "  PowerDNS Admin:  http://localhost:9191"
    echo "  MinIO Console:   http://localhost:9001"
    echo "  MinIO API:       http://localhost:9000"
    echo ""
    echo "🧪 Test your DNS setup:"
    echo "  dig @localhost -p $DNS_PORT $TEST_RECORD A"
    echo ""
    echo "💾 Create backups:"
    echo "  ./scripts/backup.sh"
    echo ""
    exit 0
else
    echo_error "❌ Some tests failed. Please check the output above for details."
    echo ""
    echo "🔧 Common fixes:"
    echo "  - Ensure all services are running: docker compose ps"
    echo "  - Check service logs: docker compose logs <service-name>"
    echo "  - Verify port conflicts: netstat -tlnp | grep -E '(5353|8081|9000|9001|9191)'"
    echo "  - Check data directory permissions: ls -la data/"
    echo ""
    exit 1
fi