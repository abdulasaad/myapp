#!/bin/bash
set -e

echo "Starting database backup..."

# Create backup directory
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Install Supabase CLI
echo "Installing Supabase CLI..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
wget -qO- https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz | tar xz
sudo mv supabase /usr/local/bin
cd -
rm -rf "$TEMP_DIR"

# Dump database structure
echo "Dumping database schema..."
supabase db dump --db-url "$SUPABASE_DB_URL" -f "$BACKUP_DIR/schema.sql"

# Dump data only
echo "Dumping database data..."
supabase db dump --db-url "$SUPABASE_DB_URL" -f "$BACKUP_DIR/data.sql" --data-only

# Dump roles
echo "Dumping database roles..."
supabase db dump --db-url "$SUPABASE_DB_URL" -f "$BACKUP_DIR/roles.sql" --role-only

# Create metadata file
cat > "$BACKUP_DIR/metadata.json" << EOF
{
  "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project_id": "$SUPABASE_PROJECT_ID",
  "backup_type": "database",
  "version": "1.0"
}
EOF

# Compress backup
echo "Compressing backup..."
tar -czf "database-backup-$(date +%Y%m%d-%H%M%S).tar.gz" "$BACKUP_DIR"

# Clean up
rm -rf "$BACKUP_DIR"

echo "Database backup completed!"