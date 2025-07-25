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