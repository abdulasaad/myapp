# App Update Feature Guide

## Overview
This guide explains how to use the mandatory app update feature for Al-Tijwal app.

## Setup Steps

### 1. Supabase Database Setup

Run the migration SQL file in your Supabase SQL editor:
```sql
-- Run the contents of app_versions_migration.sql
```

### 2. Create Storage Bucket

1. Go to your Supabase Dashboard
2. Navigate to Storage section
3. Create new bucket named `app-releases`
4. Set bucket permissions to public (for download access)

### 3. Upload New App Version

#### Step 1: Build Your App
```bash
# For Android
flutter build apk --release

# For iOS
flutter build ios --release
```

#### Step 2: Upload APK/IPA to Supabase Storage
1. Go to Storage → app-releases bucket
2. Upload your APK file (Android) or note App Store URL (iOS)
3. Copy the public URL of the uploaded file

Example URL format:
```
https://your-project.supabase.co/storage/v1/object/public/app-releases/al-tijwal-v1.0.1.apk
```

#### Step 3: Create Version Entry in Database

Insert a new record in the `app_versions` table:

```sql
INSERT INTO app_versions (
  version_code,
  version_name,
  minimum_version_code,
  download_url,
  file_size_mb,
  release_notes,
  platform,
  is_active
) VALUES (
  2,                    -- New version code (increment this)
  '1.0.1',             -- Version name shown to users
  2,                    -- Minimum required version (forces update)
  'https://your-project.supabase.co/storage/v1/object/public/app-releases/al-tijwal-v1.0.1.apk',
  25.5,                -- File size in MB
  '• Bug fixes and performance improvements
• New standalone evidence upload feature
• Enhanced location tracking',
  'android',           -- 'android' or 'ios'
  true                 -- Active status
);
```

## How It Works

### Update Check Flow
1. **On App Start**: Checks for updates in SplashScreen
2. **On App Resume**: Checks when app comes back to foreground
3. **Mandatory Updates**: Users cannot dismiss the update dialog

### Version Comparison
- Uses `version_code` (integer) for comparison
- If current version < `minimum_version_code` → Force update
- Dialog shows current version → new version

### Platform Differences
- **Android**: Downloads APK directly and triggers installation
- **iOS**: Redirects to App Store (you need to update the URL in update_service.dart)

## Testing

### Test Update Flow
1. Set your current app version to 1 in pubspec.yaml:
   ```yaml
   version: 1.0.0+1  # The +1 is the version code
   ```

2. Insert a test version in database with higher version_code:
   ```sql
   INSERT INTO app_versions (version_code, version_name, minimum_version_code, download_url, platform)
   VALUES (2, '1.0.1', 2, 'your-download-url', 'android');
   ```

3. Run the app - you should see the update dialog

### iOS App Store URL
Update the App Store URL in `lib/services/update_service.dart`:
```dart
final appStoreUrl = 'https://apps.apple.com/app/id-YOUR-APP-ID';
```

## Important Notes

1. **Version Code**: Always increment this integer for new releases
2. **Minimum Version**: Set this to force all users below this version to update
3. **File Storage**: APKs are automatically cleaned up after 7 days
4. **Network Errors**: Update checks fail silently to not block app usage
5. **iOS Updates**: Handled through App Store, not direct download

## Rollback
To disable mandatory updates temporarily:
```sql
UPDATE app_versions 
SET is_active = false 
WHERE version_code = 2;
```

## Monitoring
Check update adoption:
```sql
-- Add user version tracking if needed
SELECT version_name, COUNT(*) as users
FROM user_app_versions
GROUP BY version_name
ORDER BY version_name DESC;
```