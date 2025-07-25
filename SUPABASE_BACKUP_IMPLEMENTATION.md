# Supabase to Google Drive Backup Implementation Guide

> ⚠️ **CRITICAL SECURITY NOTICE**
> 
> This document contains sensitive credentials that should be:
> 1. **Changed immediately** after implementation
> 2. **Never committed** to version control
> 3. **Stored securely** in GitHub Secrets only
> 
> After implementation:
> - Change your Supabase password
> - Regenerate your service role key
> - Delete this file or remove all credentials

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Implementation Steps](#implementation-steps)
5. [Security Considerations](#security-considerations)
6. [Testing & Recovery](#testing--recovery)
7. [Maintenance](#maintenance)
8. [Troubleshooting](#troubleshooting)

## Overview

This guide provides a complete implementation plan for automated Supabase backups to Google Drive using GitHub Actions for the Al-Tijwal application.

### Backup Strategy
- **Frequency**: Daily database backups, weekly full backups
- **Retention**: 30 daily, 12 weekly, 12 monthly backups
- **Storage**: Google Drive (15GB free tier or paid plan)
- **Automation**: GitHub Actions with cron schedules
- **Security**: Service account authentication with minimal permissions

### What Gets Backed Up
1. **Database**
   - Complete PostgreSQL dump (schema + data)
   - User roles and permissions
   - RLS policies and functions
   
2. **Storage Objects**
   - Evidence photos
   - User uploads
   - Documents and attachments
   
3. **Configuration**
   - Supabase project settings
   - Edge function code
   - Environment configurations

## Architecture

### Platform Flow
```
┌─────────────────┐     ┌──────────────┐     ┌──────────────┐
│  GitHub Actions │────▶│   Supabase   │────▶│ Google Drive │
│   (Ubuntu VM)   │     │  Production  │     │   Storage    │
└─────────────────┘     └──────────────┘     └──────────────┘
        │                       │                      │
        │                       │                      │
        ▼                       ▼                      ▼
   Executes CLI           Data Source            Backup Storage
   Commands               - Database              - Organized folders
   - Supabase CLI        - Storage               - Compressed archives
   - Google Drive API    - Functions              - Version history
```

### Components Involved
1. **GitHub Actions**: Provides compute environment and scheduling
2. **Supabase CLI**: Performs database dumps and exports
3. **Google Cloud Service Account**: Authenticates to Google Drive
4. **Google Drive API**: Handles file uploads and management
5. **Shell Scripts**: Orchestrate backup process

## Prerequisites

### Required Accounts
- [ ] GitHub account with repository access
- [ ] Supabase project with database URL
- [ ] Google account for Drive storage
- [ ] Google Cloud Console access (free tier)

### Required Information
- [x] Supabase database connection string
- [x] Supabase project ID: `YOUR_PROJECT_ID`
- [x] Supabase service role key (for storage backup)
- [x] Repository secrets access in GitHub
- [x] Supabase URL: `https://YOUR_PROJECT_ID.supabase.co`

## Implementation Steps

### Phase 1: Google Cloud Setup

#### 1.1 Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click "Create Project"
3. Name: `al-tijwal-backups`
4. No organization needed
5. **Note**: No billing account required for this setup

#### 1.2 Enable Google Drive API
1. In Google Cloud Console, go to "APIs & Services" → "Library"
2. Search for "Google Drive API"
3. Click on it and press "Enable"
4. Wait for activation (usually instant)

#### 1.3 Create Service Account
1. Go to "IAM & Admin" → "Service Accounts"
2. Click "Create Service Account"
3. Details:
   - Name: `supabase-backup-service`
   - ID: `supabase-backup-service`
   - Description: "Service account for automated Supabase backups"
4. Click "Create and Continue"
5. Skip optional permissions (click "Continue")
6. Click "Done"

#### 1.4 Generate Service Account Key
1. Click on the created service account
2. Go to "Keys" tab
3. Click "Add Key" → "Create New Key"
4. Choose "JSON" format
5. Click "Create"
6. **IMPORTANT**: Save the downloaded JSON file securely
7. **WARNING**: This key provides access to your Google Drive - treat it like a password

#### 1.5 Setup Google Drive Folder
1. Go to [Google Drive](https://drive.google.com)
2. Create a new folder: `Al-Tijwal-Backups`
3. Right-click the folder → "Share"
4. Add the service account email (found in the JSON key file)
   - Example: `supabase-backup-service@al-tijwal-backups.iam.gserviceaccount.com`
5. Set permission to "Editor"
6. Click "Send"

### Phase 2: GitHub Repository Setup

#### 2.1 Add GitHub Secrets
1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Add the following secrets:

**SUPABASE_DB_URL**
```
postgresql://postgres.PROJECT_ID:YOUR_DATABASE_PASSWORD@aws-0-us-west-1.pooler.supabase.com:5432/postgres
```
⚠️ **Note**: Replace PROJECT_ID and YOUR_DATABASE_PASSWORD with your actual values from Supabase dashboard

**SUPABASE_PROJECT_ID**
```
YOUR_PROJECT_ID
```

**SUPABASE_SERVICE_ROLE_KEY**
```
YOUR_SERVICE_ROLE_KEY_FROM_SUPABASE_DASHBOARD
```
⚠️ **Security Warning**: Get this from your Supabase dashboard under Settings → API

**GOOGLE_DRIVE_CREDENTIALS**

This requires the JSON key file you downloaded in step 1.4. Here's how to encode it:

**On Mac/Linux (Terminal):**
```bash
# Navigate to where you saved the JSON key file, then run:
base64 -i your-service-account-key.json | tr -d '\n'

# Or specify the full path:
base64 -i ~/Downloads/al-tijwal-backups-xxxxx.json | tr -d '\n'
```

**On Windows (PowerShell):**
```powershell
# Navigate to where you saved the JSON key file, then run:
[Convert]::ToBase64String([IO.File]::ReadAllBytes("your-service-account-key.json"))

# Or specify the full path:
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Downloads\al-tijwal-backups-xxxxx.json"))
```

**Steps:**
1. Open Terminal (Mac/Linux) or PowerShell (Windows) on your local computer
2. Run the appropriate command above with your actual JSON file name
3. The command will output a long string of characters
4. Copy this entire string (it will be quite long)
5. Paste it as the value for GOOGLE_DRIVE_CREDENTIALS in GitHub Secrets

**Example output format:**
```
ewogICJ0eXBlIjogInNlcnZpY2VfYWNjb3VudCIsCiAgInByb2plY3RfaWQiOiAi...
```
(The actual string will be much longer)

**GOOGLE_DRIVE_FOLDER_ID**
```
YOUR_GOOGLE_DRIVE_FOLDER_ID
```
✅ Extract this from your Google Drive folder URL: `https://drive.google.com/drive/folders/YOUR_FOLDER_ID`

### Phase 3: Create Backup Scripts

#### 3.1 Directory Structure
```
.github/
├── workflows/
│   └── backup-supabase.yml
└── scripts/
    ├── backup-database.sh	
    ├── backup-storage.sh
    └── upload-to-drive.py
```

#### 3.2 Database Backup Script
File: `.github/scripts/backup-database.sh`
```bash
#!/bin/bash
set -e

echo "Starting database backup..."

# Create backup directory
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Install Supabase CLI
wget -qO- https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz | tar xvz
sudo mv supabase /usr/local/bin

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
```

#### 3.3 Storage Backup Script
File: `.github/scripts/backup-storage.sh`
```bash
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
export SUPABASE_URL="https://YOUR_PROJECT_ID.supabase.co"
python download_storage.py

# Compress backup
echo "Compressing storage backup..."
tar -czf "storage-backup-$(date +%Y%m%d-%H%M%S).tar.gz" "$BACKUP_DIR"

# Clean up
rm -rf "$BACKUP_DIR" download_storage.py

echo "Storage backup completed!"
```

#### 3.4 Google Drive Upload Script
File: `.github/scripts/upload-to-drive.py`
```python
#!/usr/bin/env python3
import os
import sys
import json
import base64
from datetime import datetime
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

def get_credentials():
    """Decode and return Google service account credentials"""
    creds_base64 = os.environ.get('GOOGLE_DRIVE_CREDENTIALS')
    if not creds_base64:
        raise ValueError("GOOGLE_DRIVE_CREDENTIALS not found in environment")
    
    creds_json = base64.b64decode(creds_base64).decode('utf-8')
    creds_dict = json.loads(creds_json)
    
    return service_account.Credentials.from_service_account_info(
        creds_dict,
        scopes=['https://www.googleapis.com/auth/drive.file']
    )

def upload_to_drive(file_path, folder_id):
    """Upload a file to Google Drive"""
    credentials = get_credentials()
    service = build('drive', 'v3', credentials=credentials)
    
    file_name = os.path.basename(file_path)
    file_metadata = {
        'name': file_name,
        'parents': [folder_id]
    }
    
    media = MediaFileUpload(
        file_path,
        resumable=True
    )
    
    print(f"Uploading {file_name} to Google Drive...")
    
    file = service.files().create(
        body=file_metadata,
        media_body=media,
        fields='id'
    ).execute()
    
    print(f"Upload complete! File ID: {file.get('id')}")
    return file.get('id')

def main():
    folder_id = os.environ.get('GOOGLE_DRIVE_FOLDER_ID')
    if not folder_id:
        raise ValueError("GOOGLE_DRIVE_FOLDER_ID not found in environment")
    
    # Upload all backup files
    for file_name in os.listdir('.'):
        if file_name.endswith('.tar.gz'):
            upload_to_drive(file_name, folder_id)

if __name__ == '__main__':
    main()
```

### Phase 4: GitHub Actions Workflow

#### 4.1 Main Workflow File
File: `.github/workflows/backup-supabase.yml`
```yaml
name: Supabase Backup to Google Drive

on:
  schedule:
    # Daily at 2 AM UTC
    - cron: '0 2 * * *'
  workflow_dispatch: # Allow manual trigger

env:
  SUPABASE_DB_URL: ${{ secrets.SUPABASE_DB_URL }}
  SUPABASE_PROJECT_ID: ${{ secrets.SUPABASE_PROJECT_ID }}
  SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
  GOOGLE_DRIVE_CREDENTIALS: ${{ secrets.GOOGLE_DRIVE_CREDENTIALS }}
  GOOGLE_DRIVE_FOLDER_ID: ${{ secrets.GOOGLE_DRIVE_FOLDER_ID }}

jobs:
  backup-database:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Make scripts executable
        run: chmod +x .github/scripts/*.sh

      - name: Run database backup
        run: .github/scripts/backup-database.sh

      - name: Upload database backup artifact
        uses: actions/upload-artifact@v4
        with:
          name: database-backup
          path: database-backup-*.tar.gz
          retention-days: 1

  backup-storage:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.10'

      - name: Make scripts executable
        run: chmod +x .github/scripts/*.sh

      - name: Run storage backup
        run: .github/scripts/backup-storage.sh

      - name: Upload storage backup artifact
        uses: actions/upload-artifact@v4
        with:
          name: storage-backup
          path: storage-backup-*.tar.gz
          retention-days: 1

  upload-to-drive:
    needs: [backup-database, backup-storage]
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.10'

      - name: Install dependencies
        run: |
          pip install google-auth google-auth-oauthlib google-auth-httplib2
          pip install google-api-python-client

      - name: Download database backup
        uses: actions/download-artifact@v4
        with:
          name: database-backup

      - name: Download storage backup
        uses: actions/download-artifact@v4
        with:
          name: storage-backup

      - name: Upload to Google Drive
        run: python .github/scripts/upload-to-drive.py

      - name: Cleanup old backups
        run: |
          # TODO: Implement retention policy
          echo "Cleanup will be implemented in next phase"

  notify:
    needs: upload-to-drive
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Send notification
        run: |
          if [ "${{ needs.upload-to-drive.result }}" == "success" ]; then
            echo "✅ Backup completed successfully"
          else
            echo "❌ Backup failed - check logs"
          fi
```

### Phase 5: Retention Policy Implementation

#### 5.1 Cleanup Script
File: `.github/scripts/cleanup-old-backups.py`
```python
#!/usr/bin/env python3
import os
import json
import base64
from datetime import datetime, timedelta
from google.oauth2 import service_account
from googleapiclient.discovery import build

# Retention settings
DAILY_RETENTION_DAYS = 30
WEEKLY_RETENTION_WEEKS = 12
MONTHLY_RETENTION_MONTHS = 12

def get_credentials():
    """Get Google service account credentials"""
    # Same as upload script
    pass

def list_backup_files(service, folder_id):
    """List all backup files in the folder"""
    results = service.files().list(
        q=f"'{folder_id}' in parents and trashed=false",
        fields="files(id, name, createdTime)"
    ).execute()
    
    return results.get('files', [])

def categorize_backups(files):
    """Categorize backups by type and date"""
    database_backups = []
    storage_backups = []
    
    for file in files:
        created_time = datetime.fromisoformat(file['createdTime'].replace('Z', '+00:00'))
        
        if file['name'].startswith('database-backup-'):
            database_backups.append({
                'id': file['id'],
                'name': file['name'],
                'created': created_time
            })
        elif file['name'].startswith('storage-backup-'):
            storage_backups.append({
                'id': file['id'],
                'name': file['name'],
                'created': created_time
            })
    
    return database_backups, storage_backups

def apply_retention_policy(backups):
    """Determine which backups to keep based on retention policy"""
    now = datetime.now(timezone.utc)
    to_keep = set()
    to_delete = []
    
    # Sort by creation date (newest first)
    backups.sort(key=lambda x: x['created'], reverse=True)
    
    for backup in backups:
        age_days = (now - backup['created']).days
        
        # Keep all backups from last 30 days
        if age_days <= DAILY_RETENTION_DAYS:
            to_keep.add(backup['id'])
        
        # Keep weekly backups (Sundays) for 12 weeks
        elif age_days <= WEEKLY_RETENTION_WEEKS * 7:
            if backup['created'].weekday() == 6:  # Sunday
                to_keep.add(backup['id'])
        
        # Keep monthly backups (1st of month) for 12 months
        elif age_days <= MONTHLY_RETENTION_MONTHS * 30:
            if backup['created'].day == 1:
                to_keep.add(backup['id'])
    
    # Mark others for deletion
    for backup in backups:
        if backup['id'] not in to_keep:
            to_delete.append(backup)
    
    return to_delete

def delete_old_backups(service, to_delete):
    """Delete old backup files"""
    for backup in to_delete:
        print(f"Deleting old backup: {backup['name']}")
        service.files().delete(fileId=backup['id']).execute()

def main():
    credentials = get_credentials()
    service = build('drive', 'v3', credentials=credentials)
    folder_id = os.environ.get('GOOGLE_DRIVE_FOLDER_ID')
    
    # List all backups
    files = list_backup_files(service, folder_id)
    
    # Categorize backups
    database_backups, storage_backups = categorize_backups(files)
    
    # Apply retention policy
    db_to_delete = apply_retention_policy(database_backups)
    storage_to_delete = apply_retention_policy(storage_backups)
    
    # Delete old backups
    delete_old_backups(service, db_to_delete + storage_to_delete)
    
    print(f"Cleanup complete. Deleted {len(db_to_delete) + len(storage_to_delete)} old backups.")

if __name__ == '__main__':
    main()
```

## Security Considerations

### Best Practices
1. **Service Account Permissions**
   - Only grant "Editor" access to specific backup folder
   - Never share service account key publicly
   - Rotate keys periodically (every 90 days)

2. **GitHub Secrets**
   - Use base64 encoding for JSON credentials
   - Never commit secrets to repository
   - Limit secret access to required workflows only

3. **Database Security**
   - Use read-only database user if possible
   - Ensure connection uses SSL
   - Avoid backing up sensitive data if not required

4. **Backup Encryption**
   - Consider encrypting backups before upload
   - Use GPG or similar for additional security layer

### Example Encryption Addition
```bash
# Add to backup scripts before compression
gpg --symmetric --cipher-algo AES256 --batch --passphrase "$BACKUP_ENCRYPTION_KEY" backup.tar.gz
```

## Testing & Recovery

### Testing Backup Process
1. **Manual Workflow Trigger**
   - Go to Actions tab in GitHub
   - Select "Supabase Backup to Google Drive"
   - Click "Run workflow"
   - Monitor execution logs

2. **Verify Backup Files**
   - Check Google Drive folder
   - Download a backup file
   - Extract and verify contents

3. **Test Database Connection**
   ```bash
   # Using your project URL
   psql postgresql://postgres.YOUR_PROJECT_ID:[YOUR-DATABASE-PASSWORD]@aws-0-us-west-1.pooler.supabase.com:5432/postgres -c "SELECT version();"
   ```

### Recovery Procedures

#### Database Recovery
```bash
# 1. Download backup from Google Drive
# 2. Extract the archive
tar -xzf database-backup-20250125-020000.tar.gz

# 3. Connect to Supabase database
psql $SUPABASE_DB_URL

# 4. Restore schema
\i backup-20250125-020000/schema.sql

# 5. Restore data
\i backup-20250125-020000/data.sql

# 6. Restore roles
\i backup-20250125-020000/roles.sql
```

#### Storage Recovery
```bash
# 1. Download storage backup
# 2. Extract files
tar -xzf storage-backup-20250125-020000.tar.gz

# 3. Use Supabase Dashboard or API to re-upload files
# Or use a restoration script similar to backup script
```

### Recovery Testing Schedule
- Monthly: Test database restore to development environment
- Quarterly: Full recovery drill including storage
- Annually: Complete disaster recovery exercise

## Maintenance

### Regular Tasks
1. **Weekly**
   - Verify backup jobs are running successfully
   - Check Google Drive storage usage

2. **Monthly**
   - Review backup sizes and trends
   - Test restoration procedure
   - Check for Supabase CLI updates

3. **Quarterly**
   - Rotate service account keys
   - Review and update retention policies
   - Audit access logs

### Monitoring
1. **GitHub Actions**
   - Enable email notifications for failed workflows
   - Set up Slack integration for real-time alerts

2. **Google Drive**
   - Monitor storage quota usage
   - Set alerts for quota warnings

### Updates
```bash
# Update Supabase CLI in workflow
wget -qO- https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz

# Update Python dependencies
pip install --upgrade google-api-python-client
```

## Troubleshooting

### Common Issues

#### 1. Authentication Failures
**Error**: "Invalid credentials" or "Authentication failed"
**Solution**:
- Verify service account key is correctly base64 encoded
- Check service account has access to Google Drive folder
- Ensure Google Drive API is enabled in Cloud Console

#### 2. Backup Size Issues
**Error**: "Request too large" or timeout errors
**Solution**:
- Split large databases into smaller chunks
- Increase GitHub Actions timeout
- Use incremental backups for large datasets

#### 3. Storage API Errors
**Error**: "Unauthorized" when accessing storage
**Solution**:
- Verify service role key has storage access
- Check storage bucket permissions
- Ensure buckets are not private-only

#### 4. Workflow Failures
**Error**: "Process completed with exit code 1"
**Solution**:
- Check workflow logs for specific error
- Verify all secrets are properly set
- Test scripts locally with same environment

### Debug Commands
```bash
# Test database connection
psql $SUPABASE_DB_URL -c "SELECT version();"

# Test Google Drive access
python -c "
import os
import json
import base64
from google.oauth2 import service_account
from googleapiclient.discovery import build

creds_base64 = os.environ.get('GOOGLE_DRIVE_CREDENTIALS')
creds_json = base64.b64decode(creds_base64).decode('utf-8')
creds_dict = json.loads(creds_json)

credentials = service_account.Credentials.from_service_account_info(
    creds_dict,
    scopes=['https://www.googleapis.com/auth/drive.file']
)

service = build('drive', 'v3', credentials=credentials)
results = service.files().list(pageSize=1).execute()
print('Drive access successful!')
"

# Check Supabase CLI version
supabase --version
```

### Getting Help
1. **Supabase Issues**: Check [Supabase GitHub](https://github.com/supabase/supabase/issues)
2. **Google Drive API**: See [Google Drive API Documentation](https://developers.google.com/drive/api/v3/about-sdk)
3. **GitHub Actions**: Review [GitHub Actions Documentation](https://docs.github.com/en/actions)

## Important Notes for Al-Tijwal Project

### Project-Specific Details
- **Project ID**: `YOUR_PROJECT_ID`
- **Project URL**: `https://YOUR_PROJECT_ID.supabase.co`
- **Region**: US West 1 (AWS)
- **Database Host**: `aws-0-us-west-1.pooler.supabase.com`

### Security Checklist After Implementation
- [ ] Change Supabase account password
- [ ] Regenerate service role key in Supabase dashboard
- [ ] Remove credentials from this document
- [ ] Verify GitHub Secrets are properly set
- [ ] Test backup with new credentials
- [ ] Enable 2FA on all accounts (Supabase, Google, GitHub)

### Getting Database Password
1. Log in to Supabase Dashboard
2. Go to Settings → Database
3. Find "Connection string" section
4. Click "Reveal password" to see your database password
5. Use this password in the SUPABASE_DB_URL secret

## Appendix

### Cost Estimates
- **Google Drive Storage**:
  - 15 GB free
  - 100 GB: $2/month
  - 200 GB: $3/month
  - 2 TB: $10/month

- **GitHub Actions**:
  - 2,000 minutes/month free for private repos
  - Each backup job: ~5-10 minutes
  - Monthly usage: ~300-600 minutes (well within free tier)

### Backup Size Calculations
- **Database**: 10-50 MB compressed (typical)
- **Storage**: Variable based on evidence photos
- **Monthly growth**: Estimate 1-5 GB/month
- **Annual storage**: 12-60 GB (fits in 100 GB plan)

### Alternative Solutions
1. **AWS S3**: More complex but highly scalable
2. **Backblaze B2**: Cost-effective for large backups
3. **Cloudflare R2**: No egress fees
4. **Self-hosted**: Requires infrastructure management

### References
- [Supabase CLI Documentation](https://supabase.com/docs/reference/cli)
- [Google Drive API Reference](https://developers.google.com/drive/api/v3/reference)
- [GitHub Actions Best Practices](https://docs.github.com/en/actions/guides)
- [PostgreSQL Backup Strategies](https://www.postgresql.org/docs/current/backup.html)
