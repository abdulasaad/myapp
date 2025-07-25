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
        scopes=['https://www.googleapis.com/auth/drive']
    )

def upload_to_drive(file_path, folder_id):
    """Upload a file to Google Drive"""
    credentials = get_credentials()
    service = build('drive', 'v3', credentials=credentials)
    
    # Get absolute path and verify file exists
    abs_file_path = os.path.abspath(file_path)
    file_name = os.path.basename(abs_file_path)
    
    print(f"Preparing to upload: {file_name}")
    print(f"Full path: {abs_file_path}")
    print(f"File exists: {os.path.exists(abs_file_path)}")
    print(f"File size: {os.path.getsize(abs_file_path) if os.path.exists(abs_file_path) else 'N/A'} bytes")
    
    if not os.path.exists(abs_file_path):
        raise FileNotFoundError(f"Backup file not found: {abs_file_path}")
    
    file_metadata = {
        'name': file_name,
        'parents': [folder_id]
    }
    
    media = MediaFileUpload(
        abs_file_path,
        resumable=True
    )
    
    print(f"Uploading {file_name} to Google Drive...")
    
    try:
        file = service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id'
        ).execute()
        
        print(f"Upload complete! File ID: {file.get('id')}")
        return file.get('id')
    except Exception as e:
        print(f"Upload failed with error: {e}")
        print(f"Error type: {type(e)}")
        if hasattr(e, 'resp'):
            print(f"HTTP Status: {e.resp.status}")
            print(f"Response: {e.content}")
        raise

def main():
    folder_id = os.environ.get('GOOGLE_DRIVE_FOLDER_ID')
    if not folder_id:
        raise ValueError("GOOGLE_DRIVE_FOLDER_ID not found in environment")
    
    print("Looking for backup files...")
    backup_files = []
    
    # Upload all backup files
    for file_name in os.listdir('.'):
        if file_name.endswith('.tar.gz'):
            backup_files.append(file_name)
            print(f"Found backup file: {file_name}")
    
    if not backup_files:
        print("No backup files found! Listing all files:")
        for file_name in os.listdir('.'):
            print(f"  {file_name}")
        raise ValueError("No .tar.gz backup files found to upload")
    
    # Upload each backup file
    for file_name in backup_files:
        if os.path.exists(file_name):
            upload_to_drive(file_name, folder_id)
        else:
            print(f"Warning: File {file_name} not found, skipping")

if __name__ == '__main__':
    main()