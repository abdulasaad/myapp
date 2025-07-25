#!/usr/bin/env python3
import os
import sys
import json
import requests
from datetime import datetime

def get_access_token():
    """Get OAuth2 access token for Microsoft Graph API"""
    tenant_id = os.environ.get('AZURE_TENANT_ID')
    client_id = os.environ.get('AZURE_CLIENT_ID') 
    client_secret = os.environ.get('AZURE_CLIENT_SECRET')
    
    if not all([tenant_id, client_id, client_secret]):
        raise ValueError("Missing Azure credentials. Need AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET")
    
    # OAuth2 client credentials flow
    token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
    
    data = {
        'grant_type': 'client_credentials',
        'client_id': client_id,
        'client_secret': client_secret,
        'scope': 'https://graph.microsoft.com/.default'
    }
    
    response = requests.post(token_url, data=data)
    response.raise_for_status()
    
    token_data = response.json()
    return token_data['access_token']

def get_drive_info(access_token):
    """Get the primary drive information"""
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    
    # List available drives and use the first one (usually personal OneDrive)
    drives_url = "https://graph.microsoft.com/v1.0/drives"
    response = requests.get(drives_url, headers=headers)
    response.raise_for_status()
    
    drives = response.json()
    if not drives.get('value'):
        raise ValueError("No drives found in OneDrive")
    
    return drives['value'][0]['id']

def ensure_backup_folder(access_token, drive_id):
    """Create backup folder if it doesn't exist and return folder ID"""
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    
    folder_name = "Al-Tijwal-Backups"
    
    # Check if folder exists
    search_url = f"https://graph.microsoft.com/v1.0/drives/{drive_id}/root/children"
    response = requests.get(search_url, headers=headers)
    response.raise_for_status()
    
    items = response.json()
    for item in items.get('value', []):
        if item['name'] == folder_name and 'folder' in item:
            print(f"Found existing backup folder: {folder_name}")
            return item['id']
    
    # Create folder if it doesn't exist
    create_folder_url = f"https://graph.microsoft.com/v1.0/drives/{drive_id}/root/children"
    folder_data = {
        "name": folder_name,
        "folder": {},
        "@microsoft.graph.conflictBehavior": "replace"
    }
    
    response = requests.post(create_folder_url, headers=headers, json=folder_data)
    response.raise_for_status()
    
    folder_info = response.json()
    print(f"Created backup folder: {folder_name}")
    return folder_info['id']

def upload_file_to_onedrive(access_token, drive_id, folder_id, file_path):
    """Upload a file to OneDrive backup folder"""
    file_name = os.path.basename(file_path)
    file_size = os.path.getsize(file_path)
    
    print(f"Uploading {file_name} ({file_size} bytes)...")
    
    # For files larger than 4MB, we should use resumable upload
    # For now, using simple upload (works for most backup files)
    upload_url = f"https://graph.microsoft.com/v1.0/drives/{drive_id}/items/{folder_id}:/{file_name}:/content"
    
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/octet-stream'
    }
    
    with open(file_path, 'rb') as file_data:
        response = requests.put(upload_url, headers=headers, data=file_data)
        response.raise_for_status()
    
    file_info = response.json()
    print(f"✅ Upload complete: {file_info['name']} (ID: {file_info['id']})")
    return file_info['id']

def main():
    """Upload all backup files to OneDrive"""
    try:
        print("Starting OneDrive upload...")
        
        # Get access token
        access_token = get_access_token()
        print("✅ Obtained access token")
        
        # Get drive info
        drive_id = get_drive_info(access_token)
        print(f"✅ Using drive: {drive_id}")
        
        # Ensure backup folder exists
        folder_id = ensure_backup_folder(access_token, drive_id)
        print(f"✅ Backup folder ready: {folder_id}")
        
        # Upload all backup files
        uploaded_files = []
        for file_name in os.listdir('.'):
            if file_name.endswith('.tar.gz'):
                file_id = upload_file_to_onedrive(access_token, drive_id, folder_id, file_name)
                uploaded_files.append(file_name)
        
        if uploaded_files:
            print(f"\n🎉 Successfully uploaded {len(uploaded_files)} backup files:")
            for file_name in uploaded_files:
                print(f"   - {file_name}")
        else:
            print("⚠️  No backup files found to upload")
            
    except Exception as e:
        print(f"❌ Upload failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()