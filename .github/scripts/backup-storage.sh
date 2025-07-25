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
import sys

url = os.environ.get('SUPABASE_URL')
key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')
backup_dir = os.environ.get('BACKUP_DIR')

if not url or not key:
    print("Error: Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY")
    sys.exit(1)

print(f"Connecting to Supabase at {url}")
supabase = create_client(url, key)

try:
    # List all buckets
    buckets = supabase.storage.list_buckets()
    print(f"Found {len(buckets)} storage buckets")
    
    if not buckets:
        print("No storage buckets found. Creating empty backup.")
        # Create empty file to indicate no storage
        with open(os.path.join(backup_dir, 'NO_STORAGE_BUCKETS.txt'), 'w') as f:
            f.write("No storage buckets found at backup time\n")
        sys.exit(0)
    
    for bucket in buckets:
        # Handle both dict and object formats
        try:
            bucket_name = bucket.name if hasattr(bucket, 'name') else bucket.get('name', str(bucket))
        except:
            print(f"Warning: Could not get bucket name, skipping: {bucket}")
            continue
            
        print(f"Backing up bucket: {bucket_name}")
        
        # Create bucket directory
        bucket_path = os.path.join(backup_dir, bucket_name)
        os.makedirs(bucket_path, exist_ok=True)
        
        try:
            # List all files in the bucket
            files = supabase.storage.from_(bucket_name).list()
            
            if not files:
                print(f"  No files in bucket {bucket_name}")
                continue
                
            for file_obj in files:
                try:
                    # Get file name
                    file_name = file_obj.get('name') if isinstance(file_obj, dict) else getattr(file_obj, 'name', str(file_obj))
                    print(f"  Downloading: {file_name}")
                    
                    # Download file
                    res = supabase.storage.from_(bucket_name).download(file_name)
                    
                    # Save file
                    local_path = os.path.join(bucket_path, file_name)
                    os.makedirs(os.path.dirname(local_path), exist_ok=True)
                    
                    with open(local_path, 'wb') as f:
                        f.write(res)
                except Exception as e:
                    print(f"  Error downloading {file_name}: {str(e)}")
        except Exception as e:
            print(f"Error listing files in bucket {bucket_name}: {str(e)}")
    
    print("Storage backup completed successfully!")
    
except Exception as e:
    print(f"Error during storage backup: {str(e)}")
    sys.exit(1)
EOF

# Run the download script
export SUPABASE_URL="https://jnuzpixgfskjcoqmgkxb.supabase.co"
export BACKUP_DIR="$BACKUP_DIR"
python3 download_storage.py || echo "Storage backup completed with warnings"

# Compress backup
echo "Compressing storage backup..."
tar -czf "storage-backup-$(date +%Y%m%d-%H%M%S).tar.gz" "$BACKUP_DIR"

# Clean up
rm -rf "$BACKUP_DIR" download_storage.py

echo "Storage backup completed!"