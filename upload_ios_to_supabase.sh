#!/bin/bash

# Supabase configuration
SUPABASE_URL="https://otsgnyqdzwiruxasmlbo.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90c2dueXFkendpcnV4YXNtbGJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE0MTU5NjgsImV4cCI6MjAzNjk5MTk2OH0.ZgqIz6PDlt0_moong3PbKLNsKzpqMo8pFUZGVkvCmsA"

# File details
IPA_FILE="/Users/abdullahsaad/AL-Tijwal/myapp/myapp/build/ios/iphoneos/Al-Tijwal-iOS.ipa"
TIMESTAMP=$(date +%s)
FILE_NAME="Al-Tijwal-iOS-${TIMESTAMP}.ipa"

# Check if file exists
if [ ! -f "$IPA_FILE" ]; then
    echo "Error: IPA file not found at $IPA_FILE"
    exit 1
fi

# Get file size in MB
FILE_SIZE_BYTES=$(stat -f%z "$IPA_FILE" 2>/dev/null || stat -c%s "$IPA_FILE" 2>/dev/null)
FILE_SIZE_MB=$(echo "scale=2; $FILE_SIZE_BYTES / 1024 / 1024" | bc)

echo "Uploading iOS IPA to Supabase..."
echo "File: $IPA_FILE"
echo "Size: ${FILE_SIZE_MB} MB"

# Upload file to Supabase storage
RESPONSE=$(curl -X POST \
  "${SUPABASE_URL}/storage/v1/object/app-updates/ios/${FILE_NAME}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@${IPA_FILE}" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo "✅ Upload successful!"
    
    # Construct public URL
    PUBLIC_URL="${SUPABASE_URL}/storage/v1/object/public/app-updates/ios/${FILE_NAME}"
    
    echo ""
    echo "=== iOS App Upload Complete ==="
    echo "File Name: $FILE_NAME"
    echo "File Size: ${FILE_SIZE_MB} MB"
    echo "Public URL: $PUBLIC_URL"
    echo ""
    echo "To add this version to the app_versions table, run this SQL:"
    echo ""
    echo "INSERT INTO public.app_versions ("
    echo "  version_code,"
    echo "  version_name,"
    echo "  minimum_version_code,"
    echo "  download_url,"
    echo "  file_size_mb,"
    echo "  release_notes,"
    echo "  platform,"
    echo "  is_active"
    echo ") VALUES ("
    echo "  1, -- Update with your actual build number"
    echo "  '1.0.0', -- Update with your actual version"
    echo "  1, -- Minimum version required"
    echo "  '${PUBLIC_URL}',"
    echo "  ${FILE_SIZE_MB},"
    echo "  'Initial iOS release',"
    echo "  'ios',"
    echo "  true"
    echo ");"
else
    echo "❌ Upload failed with HTTP code: $HTTP_CODE"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi