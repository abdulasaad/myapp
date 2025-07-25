#!/usr/bin/env python3
import os
import json
import base64
from google.oauth2 import service_account
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

def get_credentials():
    """Get Google credentials (OAuth or Service Account)"""
    creds_base64 = os.environ.get('GOOGLE_DRIVE_CREDENTIALS')
    if not creds_base64:
        raise ValueError("GOOGLE_DRIVE_CREDENTIALS not found in environment")
    
    creds_json = base64.b64decode(creds_base64).decode('utf-8')
    creds_dict = json.loads(creds_json)
    
    # Check if this is OAuth credentials (has client_id) or service account (has client_email)
    if 'client_id' in creds_dict and 'client_secret' in creds_dict:
        # OAuth credentials - for GitHub Actions, we'll use a different approach
        print("OAuth credentials detected - using service account fallback for automation")
        # For automated scripts, we still need service account. OAuth requires interactive auth.
        # Let's try the service account approach but with better error handling
        raise ValueError("OAuth credentials require interactive authentication. Please add your email as a test user in the OAuth consent screen, or use service account with domain delegation.")
    
    elif 'client_email' in creds_dict:
        # Service account credentials
        print("Service account credentials detected")
        credentials = service_account.Credentials.from_service_account_info(
            creds_dict,
            scopes=[
                'https://www.googleapis.com/auth/drive',
                'https://www.googleapis.com/auth/drive.file',
                'https://www.googleapis.com/auth/drive.metadata'
            ]
        )
        
        # Try domain delegation if possible
        user_email = os.environ.get('GOOGLE_DRIVE_USER_EMAIL', 'abdulasaad95@gmail.com')
        try:
            delegated_credentials = credentials.with_subject(user_email)
            print(f"Using delegated credentials for {user_email}")
            return delegated_credentials
        except Exception as e:
            print(f"Domain delegation not available: {e}")
            print("Using service account directly (may have storage limitations)")
            return credentials
    
    else:
        raise ValueError("Credentials format not recognized. Expected OAuth or service account JSON.")

def test_drive_access():
    """Test Google Drive access and folder permissions"""
    try:
        credentials = get_credentials()
        service = build('drive', 'v3', credentials=credentials)
        folder_id = os.environ.get('GOOGLE_DRIVE_FOLDER_ID')
        
        print(f"Testing Google Drive access...")
        print(f"Folder ID: {folder_id}")
        
        # Test 1: List files in root
        print("\n1. Testing basic Drive access...")
        results = service.files().list(pageSize=5, fields="files(id, name)").execute()
        files = results.get('files', [])
        print(f"✅ Can access Drive - found {len(files)} files in root")
        
        # Test 2: Check specific folder access
        print(f"\n2. Testing folder access...")
        try:
            folder_info = service.files().get(fileId=folder_id).execute()
            print(f"✅ Folder found: {folder_info.get('name')}")
            print(f"   Folder ID: {folder_info.get('id')}")
            print(f"   Folder type: {folder_info.get('mimeType')}")
        except Exception as e:
            print(f"❌ Cannot access folder: {e}")
            return False
        
        # Test 3: List files in target folder
        print(f"\n3. Testing folder contents...")
        try:
            results = service.files().list(
                q=f"'{folder_id}' in parents and trashed=false",
                fields="files(id, name, createdTime)"
            ).execute()
            files = results.get('files', [])
            print(f"✅ Folder contents: {len(files)} files")
            for file in files[:5]:  # Show first 5 files
                print(f"   - {file.get('name')} (created: {file.get('createdTime')})")
        except Exception as e:
            print(f"❌ Cannot list folder contents: {e}")
            return False
        
        # Test 4: Test write permissions by creating a test file
        print(f"\n4. Testing write permissions...")
        try:
            test_metadata = {
                'name': 'test-backup-access.txt',
                'parents': [folder_id]
            }
            
            # Create a simple test file
            import io
            from googleapiclient.http import MediaIoBaseUpload
            
            test_content = "This is a test file to verify backup access.\nCreated by backup system test."
            fh = io.BytesIO(test_content.encode())
            media = MediaIoBaseUpload(fh, mimetype='text/plain')
            
            file = service.files().create(
                body=test_metadata,
                media_body=media,
                fields='id,name'
            ).execute()
            
            print(f"✅ Write test successful - created file: {file.get('name')}")
            print(f"   File ID: {file.get('id')}")
            
            # Clean up test file
            service.files().delete(fileId=file.get('id')).execute()
            print(f"✅ Test file cleaned up")
            
        except Exception as e:
            print(f"❌ Write permission test failed: {e}")
            return False
        
        print(f"\n🎉 All tests passed! Google Drive backup is properly configured.")
        return True
        
    except Exception as e:
        print(f"❌ Drive access test failed: {e}")
        return False

if __name__ == '__main__':
    test_drive_access()