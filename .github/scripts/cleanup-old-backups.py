#!/usr/bin/env python3
import os
import json
import base64
from datetime import datetime, timedelta, timezone
from google.oauth2 import service_account
from googleapiclient.discovery import build

# Retention settings
DAILY_RETENTION_DAYS = 30
WEEKLY_RETENTION_WEEKS = 12
MONTHLY_RETENTION_MONTHS = 12

def get_credentials():
    """Get Google service account credentials"""
    creds_base64 = os.environ.get('GOOGLE_DRIVE_CREDENTIALS')
    if not creds_base64:
        raise ValueError("GOOGLE_DRIVE_CREDENTIALS not found in environment")
    
    creds_json = base64.b64decode(creds_base64).decode('utf-8')
    creds_dict = json.loads(creds_json)
    
    return service_account.Credentials.from_service_account_info(
        creds_dict,
        scopes=['https://www.googleapis.com/auth/drive']
    )

def list_backup_files(service, folder_id):
    """List all backup files in the folder"""
    all_files = []
    page_token = None
    
    while True:
        results = service.files().list(
            q=f"'{folder_id}' in parents and trashed=false",
            fields="nextPageToken, files(id, name, createdTime)",
            pageToken=page_token,
            pageSize=100
        ).execute()
        
        all_files.extend(results.get('files', []))
        page_token = results.get('nextPageToken', None)
        
        if page_token is None:
            break
    
    return all_files

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
        try:
            print(f"Deleting old backup: {backup['name']}")
            service.files().delete(fileId=backup['id']).execute()
        except Exception as e:
            print(f"Error deleting {backup['name']}: {str(e)}")

def main():
    try:
        credentials = get_credentials()
        service = build('drive', 'v3', credentials=credentials)
        folder_id = os.environ.get('GOOGLE_DRIVE_FOLDER_ID')
        
        if not folder_id:
            raise ValueError("GOOGLE_DRIVE_FOLDER_ID not found in environment")
        
        print("Starting backup cleanup...")
        
        # List all backups
        files = list_backup_files(service, folder_id)
        print(f"Found {len(files)} total files in backup folder")
        
        # Categorize backups
        database_backups, storage_backups = categorize_backups(files)
        print(f"Found {len(database_backups)} database backups and {len(storage_backups)} storage backups")
        
        # Apply retention policy
        db_to_delete = apply_retention_policy(database_backups)
        storage_to_delete = apply_retention_policy(storage_backups)
        
        total_to_delete = len(db_to_delete) + len(storage_to_delete)
        
        if total_to_delete > 0:
            print(f"Deleting {total_to_delete} old backups...")
            # Delete old backups
            delete_old_backups(service, db_to_delete + storage_to_delete)
        else:
            print("No old backups to delete")
        
        print(f"Cleanup complete. Deleted {total_to_delete} old backups.")
        
    except Exception as e:
        print(f"Error during cleanup: {str(e)}")
        exit(1)

if __name__ == '__main__':
    main()