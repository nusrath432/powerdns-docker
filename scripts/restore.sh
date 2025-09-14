#!/bin/bash

# PowerDNS Docker Compose Restore Script
# This script restores from backup archives

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
BACKUP_DIR="$PROJECT_DIR/backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo_prompt() {
    echo -e "${BLUE}[PROMPT]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [backup_file]"
    echo ""
    echo "If no backup file is specified, this script will list available backups."
    echo ""
    echo "Examples:"
    echo "  $0                                    # List available backups"
    echo "  $0 powerdns_backup_20240314_120000.tar.gz   # Restore specific backup"
    echo ""
}

# Function to list available backups
list_backups() {
    echo_info "Available backups in $BACKUP_DIR:"
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR"/*.tar.gz 2>/dev/null)" ]; then
        ls -lt "$BACKUP_DIR"/powerdns_backup_*.tar.gz | while read -r line; do
            filename=$(echo "$line" | awk '{print $NF}')
            basename_file=$(basename "$filename")
            size=$(echo "$line" | awk '{print $5}')
            date_time=$(echo "$line" | awk '{print $6, $7, $8}')
            echo "  $basename_file (${size} bytes, $date_time)"
        done
    else
        echo_warn "No backups found in $BACKUP_DIR"
        return 1
    fi
}

# Function to confirm action
confirm_action() {
    echo_prompt "$1"
    read -p "Type 'yes' to continue: " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        echo_info "Operation cancelled."
        exit 0
    fi
}

# Main script
echo_info "PowerDNS Docker Compose Restore Script"

# If no arguments provided, list available backups
if [ $# -eq 0 ]; then
    list_backups
    echo ""
    echo_info "To restore a backup, run: $0 <backup_filename>"
    exit 0
fi

# Check if backup file argument is provided
BACKUP_FILE="$1"

# If just filename provided, prepend backup directory path
if [[ "$BACKUP_FILE" != /* ]]; then
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo_error "Backup file not found: $BACKUP_FILE"
    echo ""
    list_backups
    exit 1
fi

echo_info "Restore details:"
echo_info "  Backup file: $BACKUP_FILE"
echo_info "  Project directory: $PROJECT_DIR"
echo_info "  Target data directory: $DATA_DIR"

# Get backup file size and date
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
BACKUP_DATE=$(date -r "$BACKUP_FILE" '+%Y-%m-%d %H:%M:%S')
echo_info "  Backup size: $BACKUP_SIZE"
echo_info "  Backup date: $BACKUP_DATE"

# Check if services are running
if docker compose -f "$PROJECT_DIR/docker-compose.yml" ps | grep -q "Up"; then
    echo_warn "Services are currently running. You should stop them before restoring:"
    echo_warn "  docker compose down"
    echo_warn ""
    confirm_action "Do you want to continue with the restore anyway? This may cause data inconsistency."
fi

# Warn about data overwrite
if [ -d "$DATA_DIR" ] && [ "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
    echo_warn "Existing data will be overwritten!"
    echo_warn "Current data directories:"
    find "$DATA_DIR" -type d -name "*" | sed 's/^/    /' | head -10
    echo_warn ""
    confirm_action "This will OVERWRITE all existing data. Are you sure you want to continue?"
fi

# Create backup of current data if it exists
if [ -d "$DATA_DIR" ] && [ "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
    CURRENT_BACKUP="$BACKUP_DIR/pre_restore_backup_$(date +"%Y%m%d_%H%M%S").tar.gz"
    echo_info "Creating backup of current data: $CURRENT_BACKUP"
    cd "$PROJECT_DIR"
    tar -czf "$CURRENT_BACKUP" data/ || echo_warn "Failed to create pre-restore backup"
fi

# Extract backup
echo_info "Extracting backup..."
cd "$PROJECT_DIR"

# Remove existing data directory
if [ -d "$DATA_DIR" ]; then
    echo_info "Removing existing data directory..."
    rm -rf "$DATA_DIR"
fi

# Extract the backup
if tar -xzf "$BACKUP_FILE"; then
    echo_info "Backup extracted successfully!"
    
    # Show what was restored
    echo_info "Restored directories:"
    find data -type d -name "*" 2>/dev/null | sed 's/^/    /' || echo_warn "No data directories found"
    
    # Show file counts
    for dir in data/*/; do
        if [ -d "$dir" ]; then
            file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
            echo_info "  $(basename "$dir"): $file_count files restored"
        fi
    done
    
    echo_info "Restore completed successfully!"
    echo_info ""
    echo_info "Next steps:"
    echo_info "  1. Start services: docker compose up -d"
    echo_info "  2. Check service status: docker compose ps"
    echo_info "  3. View logs: docker compose logs -f"
    
else
    echo_error "Failed to extract backup!"
    exit 1
fi