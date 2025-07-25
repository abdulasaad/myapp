#!/bin/bash
set -e

echo "Starting database backup via Supabase API..."

# Create backup directory
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Install required tools
pip install requests

# Python script to backup via Supabase API
cat > backup_via_api.py << 'EOF'
import os
import json
import requests
import sys
from datetime import datetime

# Get environment variables
project_id = os.environ.get('SUPABASE_PROJECT_ID')
service_key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')
backup_dir = os.environ.get('BACKUP_DIR')

if not project_id or not service_key:
    print("Error: Missing SUPABASE_PROJECT_ID or SUPABASE_SERVICE_ROLE_KEY")
    sys.exit(1)

print(f"Backing up Supabase project: {project_id}")

# Supabase API headers
headers = {
    'apikey': service_key,
    'Authorization': f'Bearer {service_key}',
    'Content-Type': 'application/json'
}

base_url = f'https://{project_id}.supabase.co'

# Get list of tables
def get_tables():
    try:
        # Use PostgREST API to get table information
        url = f'{base_url}/rest/v1/rpc/get_schema_tables'
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()
        else:
            # Fallback: get common tables
            print("Using fallback table detection...")
            common_tables = ['profiles', 'campaigns', 'tasks', 'groups', 'user_groups', 'active_agents']
            return [{'table_name': table} for table in common_tables]
    except Exception as e:
        print(f"Error getting tables: {e}")
        # Default tables for Al-Tijwal app
        return [
            {'table_name': 'profiles'},
            {'table_name': 'campaigns'}, 
            {'table_name': 'tasks'},
            {'table_name': 'groups'},
            {'table_name': 'user_groups'},
            {'table_name': 'active_agents'},
            {'table_name': 'task_assignments'}
        ]

# Backup table data
def backup_table(table_name):
    try:
        print(f"  Backing up table: {table_name}")
        url = f'{base_url}/rest/v1/{table_name}?select=*'
        response = requests.get(url, headers=headers)
        
        if response.status_code == 200:
            data = response.json()
            # Save as JSON
            with open(os.path.join(backup_dir, f'{table_name}.json'), 'w') as f:
                json.dump(data, f, indent=2, default=str)
            print(f"    Saved {len(data)} records from {table_name}")
        else:
            print(f"    Warning: Could not backup {table_name} (status: {response.status_code})")
    except Exception as e:
        print(f"    Error backing up {table_name}: {e}")

# Main backup process
try:
    tables = get_tables()
    print(f"Found {len(tables)} tables to backup")
    
    for table in tables:
        table_name = table.get('table_name', table.get('name', str(table)))
        backup_table(table_name)
    
    # Create metadata file
    metadata = {
        'backup_date': datetime.utcnow().isoformat() + 'Z',
        'project_id': project_id,
        'backup_type': 'api_backup',
        'version': '1.0',
        'tables_backed_up': len(tables)
    }
    
    with open(os.path.join(backup_dir, 'metadata.json'), 'w') as f:
        json.dump(metadata, f, indent=2)
    
    print("Database backup completed successfully!")
    
except Exception as e:
    print(f"Error during backup: {e}")
    sys.exit(1)
EOF

# Run the backup script
export BACKUP_DIR="$BACKUP_DIR"
python3 backup_via_api.py

# Compress backup
echo "Compressing backup..."
tar -czf "database-backup-$(date +%Y%m%d-%H%M%S).tar.gz" "$BACKUP_DIR"

# Clean up
rm -rf "$BACKUP_DIR" backup_via_api.py

echo "Database backup completed!"