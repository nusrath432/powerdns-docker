#!/bin/bash

# PowerDNS Docker Compose Backup Script
# This script creates backups of all persistent data directories

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
BACKUP_DIR="$PROJECT_DIR/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="powerdns_backup_$TIMESTAMP"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if data directory exists
if [ ! -d "$DATA_DIR" ]; then
    echo_error "Data directory not found: $DATA_DIR"
    exit 1
fi

echo_info "Starting PowerDNS backup..."
echo_info "Project directory: $PROJECT_DIR"
echo_info "Data directory: $DATA_DIR"
echo_info "Backup directory: $BACKUP_DIR"
echo_info "Backup name: $BACKUP_NAME"

# Check if services are running
if docker compose -f "$PROJECT_DIR/docker-compose.yml" ps | grep -q "Up"; then
    echo_warn "Some services are running. Consider stopping them for a consistent backup:"
    echo_warn "  docker compose down"
    echo_warn "Continuing with backup anyway..."
fi

# Create tar.gz backup
echo_info "Creating compressed backup archive..."
cd "$PROJECT_DIR"
# Use sudo to handle permission issues with service-owned files
sudo tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
    --exclude='data/.gitkeep' \
    data/ config/ .env docker-compose.yml

# Change ownership of backup file to current user
sudo chown "$(whoami):$(whoami)" "$BACKUP_DIR/$BACKUP_NAME.tar.gz"

if [ $? -eq 0 ]; then
    echo_info "Backup created successfully: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
    
    # Display backup size
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)
    echo_info "Backup size: $BACKUP_SIZE"
    
    # List contents of data directories
    echo_info "Backup contents:"
    echo "  Data directories:"
    find data -type d -name "*" | sed 's/^/    /'
    
    # Show number of files in each directory
    for dir in data/*/; do
        if [ -d "$dir" ]; then
            file_count=$(find "$dir" -type f | wc -l)
            echo_info "  $(basename "$dir"): $file_count files"
        fi
    done
else
    echo_error "Backup failed!"
    exit 1
fi

# Cleanup old backups (keep last 5)
echo_info "Cleaning up old backups (keeping last 5)..."
ls -t "$BACKUP_DIR"/powerdns_backup_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f

echo_info "Backup completed successfully!"
echo_info "To restore: tar -xzf $BACKUP_DIR/$BACKUP_NAME.tar.gz"