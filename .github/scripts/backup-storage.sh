#!/bin/bash
set -e

echo "Starting storage backup..."

# Create backup directory
BACKUP_DIR="storage-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Install required tools
pip install supabase

# Python script to download storage objects
cat > download_storage.py << EOF
import os
import json
from supabase import create_client

url = os.environ.get('SUPABASE_URL')
key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')
backup_dir = os.environ.get('BACKUP_DIR')

supabase = create_client(url, key)

# List all buckets
buckets = supabase.storage.list_buckets()
print(f"Found {len(buckets)} storage buckets")

if not buckets:
    print("No storage buckets found. Skipping storage backup.")
    exit(0)

for bucket in buckets:
    # Handle both dict and object formats
    if hasattr(bucket, 'name'):
        bucket_name = bucket.name
    else:
        bucket_name = bucket['name']
    print(f"Backing up bucket: {bucket_name}")
    
    # Create bucket directory
    bucket_path = os.path.join(backup_dir, bucket_name)
    os.makedirs(bucket_path, exist_ok=True)
    
    # List and download all files
    files = supabase.storage.from_(bucket_name).list()
    
    for file in files:
        file_name = file['name']
        print(f"  Downloading: {file_name}")
        
        try:
            # Download file
            res = supabase.storage.from_(bucket_name).download(file_name)
            
            # Save file
            local_path = os.path.join(bucket_path, file_name)
            os.makedirs(os.path.dirname(local_path), exist_ok=True)
            
            with open(local_path, 'wb') as f:
                f.write(res)
        except Exception as e:
            print(f"  Error downloading {file_name}: {str(e)}")

print("Storage backup completed!")
EOF

# Run the download script
export SUPABASE_URL="https://jnuzpixgfskjcoqmgkxb.supabase.co"
export BACKUP_DIR="$BACKUP_DIR"
python download_storage.py

# Compress backup
echo "Compressing storage backup..."
tar -czf "storage-backup-$(date +%Y%m%d-%H%M%S).tar.gz" "$BACKUP_DIR"

# Clean up
rm -rf "$BACKUP_DIR" download_storage.py

echo "Storage backup completed!"