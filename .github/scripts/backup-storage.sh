#!/bin/bash
set -e

echo "Starting storage backup..."

# Create backup directory
BACKUP_DIR="storage-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Install required tools
pip install supabase

# Python script to download storage objects
cat > download_storage.py << 'EOF'
import os
import json
from supabase import create_client

url = os.environ.get('SUPABASE_URL')
key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')
supabase = create_client(url, key)

# List all buckets
buckets = supabase.storage.list_buckets()

for bucket in buckets:
    bucket_name = bucket.name
    print(f"Backing up bucket: {bucket_name}")
    
    # Create bucket directory
    os.makedirs(f"$BACKUP_DIR/{bucket_name}", exist_ok=True)
    
    # List and download all files
    files = supabase.storage.from_(bucket_name).list()
    
    for file in files:
        file_path = file['name']
        print(f"  Downloading: {file_path}")
        
        # Download file
        res = supabase.storage.from_(bucket_name).download(file_path)
        
        # Save file
        local_path = f"$BACKUP_DIR/{bucket_name}/{file_path}"
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        
        with open(local_path, 'wb') as f:
            f.write(res)

print("Storage backup completed!")
EOF

# Run the download script
export SUPABASE_URL="https://jnuzpixgfskjcoqmgkxb.supabase.co"
python download_storage.py

# Compress backup
echo "Compressing storage backup..."
tar -czf "storage-backup-$(date +%Y%m%d-%H%M%S).tar.gz" "$BACKUP_DIR"

# Clean up
rm -rf "$BACKUP_DIR" download_storage.py

echo "Storage backup completed!"