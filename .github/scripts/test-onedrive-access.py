#!/usr/bin/env python3
import os
import json
import requests
import base64
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

def test_onedrive_access():
    """Test OneDrive access and folder permissions"""
    try:
        print("Testing OneDrive access...")
        
        # Get access token
        print("1. Getting access token...")
        access_token = get_access_token()
        print("✅ Successfully obtained access token")
        
        headers = {
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json'
        }
        
        # Test 2: List user's OneDrive
        print("\n2. Testing OneDrive access...")
        # For application permissions, we need to access a specific user's drive
        # Let's try to list available drives first
        drives_url = "https://graph.microsoft.com/v1.0/drives"
        response = requests.get(drives_url, headers=headers)
        
        if response.status_code == 200:
            drives = response.json()
            print(f"✅ Found {len(drives.get('value', []))} drives")
            
            if drives.get('value'):
                drive_id = drives['value'][0]['id']
                print(f"   Using drive: {drive_id}")
                
                # Test 3: List root folder contents
                print("\n3. Testing folder listing...")
                root_url = f"https://graph.microsoft.com/v1.0/drives/{drive_id}/root/children"
                response = requests.get(root_url, headers=headers)
                
                if response.status_code == 200:
                    items = response.json()
                    print(f"✅ Found {len(items.get('value', []))} items in root")
                    
                    # Test 4: Create test folder
                    print("\n4. Testing folder creation...")
                    folder_name = "Al-Tijwal-Backups"
                    create_folder_url = f"https://graph.microsoft.com/v1.0/drives/{drive_id}/root/children"
                    
                    folder_data = {
                        "name": folder_name,
                        "folder": {},
                        "@microsoft.graph.conflictBehavior": "replace"
                    }
                    
                    response = requests.post(create_folder_url, headers=headers, json=folder_data)
                    
                    if response.status_code in [200, 201]:
                        folder_info = response.json()
                        folder_id = folder_info['id']
                        print(f"✅ Created/found backup folder: {folder_name}")
                        print(f"   Folder ID: {folder_id}")
                        
                        # Test 5: Upload test file
                        print("\n5. Testing file upload...")
                        test_content = f"Test backup file created at {datetime.now()}"
                        test_filename = "test-backup.txt"
                        
                        upload_url = f"https://graph.microsoft.com/v1.0/drives/{drive_id}/items/{folder_id}:/{test_filename}:/content"
                        
                        upload_headers = {
                            'Authorization': f'Bearer {access_token}',
                            'Content-Type': 'text/plain'
                        }
                        
                        response = requests.put(upload_url, headers=upload_headers, data=test_content.encode())
                        
                        if response.status_code in [200, 201]:
                            file_info = response.json()
                            print(f"✅ Upload successful: {file_info['name']}")
                            print(f"   File size: {file_info['size']} bytes")
                            
                            # Clean up test file
                            delete_url = f"https://graph.microsoft.com/v1.0/drives/{drive_id}/items/{file_info['id']}"
                            requests.delete(delete_url, headers=headers)
                            print("✅ Test file cleaned up")
                            
                        else:
                            print(f"❌ Upload failed: {response.status_code} - {response.text}")
                            return False
                            
                    else:
                        print(f"❌ Folder creation failed: {response.status_code} - {response.text}")
                        return False
                        
                else:
                    print(f"❌ Folder listing failed: {response.status_code} - {response.text}")
                    return False
                    
            else:
                print("❌ No drives found")
                return False
                
        else:
            print(f"❌ Drive access failed: {response.status_code} - {response.text}")
            return False
            
        print(f"\n🎉 All tests passed! OneDrive backup is properly configured.")
        print(f"📁 Backup folder ID: {folder_id}")
        return True
        
    except Exception as e:
        print(f"❌ OneDrive access test failed: {e}")
        return False

if __name__ == '__main__':
    test_onedrive_access()