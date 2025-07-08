# AL-Tijwal Push Notification Setup Guide

This guide explains how to set up the comprehensive push notification system that allows administrators to send notifications to agents and managers with proper background delivery.

## 🎯 Overview

The notification system includes:
- **Admin Interface**: Send notifications to selected users
- **Firebase Cloud Messaging**: Server-side push notification delivery
- **Background Notifications**: Receive notifications when app is closed
- **User Separation**: Proper FCM token management per user
- **Multiple Fallbacks**: Edge Function → Direct FCM → Local notifications

## 📋 Prerequisites

- Firebase project with Cloud Messaging enabled
- Supabase project with Edge Functions capability
- Google Cloud Console access for service account management

## 🔧 Setup Instructions

### 1. Firebase Configuration

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project or select existing `al-tijwal-notifications`
3. Enable **Cloud Messaging** in project settings

#### Enable Cloud Messaging API
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your Firebase project
3. Navigate to **APIs & Services** → **Library**
4. Search for "Firebase Cloud Messaging API"
5. Click **Enable**

#### Create Service Account
1. In Firebase Console: **Project Settings** → **Service Accounts**
2. Click **Generate new private key**
3. Download the JSON file (contains service account credentials)
4. **Alternative**: Create in Google Cloud Console:
   - **IAM & Admin** → **Service Accounts**
   - **Create Service Account**
   - Name: `fcm-notifications-service`
   - Role: `Firebase Admin SDK Administrator Service Agent`

### 2. Service Account Permissions

#### Required Roles
The service account needs these permissions:
- **Firebase Admin SDK Administrator Service Agent**
- **Firebase Service Management Service Agent** (if available)

#### Add Permissions (Google Cloud Console)
1. Go to **IAM & Admin** → **IAM**
2. Find your service account
3. Click **Edit** (pencil icon)
4. **Add Role** → Select required roles above
5. **Save**

### 3. Supabase Configuration

#### Deploy Edge Function
```bash
# Navigate to project directory
cd /path/to/your/flutter/project

# Link to Supabase project
supabase login
supabase link --project-ref YOUR_PROJECT_REF

# Deploy the notification edge function
supabase functions deploy send-push-notification
```

#### Set Environment Variables
1. **Via Supabase Dashboard**:
   - Go to **Project Settings** → **Edge Functions** → **Secrets**
   - Add new secret:
     - **Name**: `FIREBASE_SERVICE_ACCOUNT_KEY`
     - **Value**: Paste entire JSON content from downloaded service account file

2. **Via Supabase CLI**:
```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT_KEY='{"type":"service_account","project_id":"your-project",...}'
```

### 4. Database Setup

The notification system requires these database components (already included):

#### Tables
- `notifications`: Stores notification records
- `profiles`: Stores user FCM tokens

#### RPC Functions
- `create_notification`: Creates notifications with proper validation
- `get_unread_notification_count`: Returns unread count for users
- `mark_notification_read`: Marks individual notifications as read
- `mark_all_notifications_read`: Marks all user notifications as read

### 5. App Configuration

#### Android Permissions
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

#### iOS Permissions
Add to `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>background-fetch</string>
</array>
```

## 🚀 Usage

### Admin Interface
1. **Login as Admin** → Navigate to **Admin Dashboard**
2. **Click "Send Notification"** card
3. **Select recipient** (filter by role: All/Managers/Agents)
4. **Compose notification** (title and message)
5. **Preview notification** in real-time
6. **Send notification** → Recipients receive instantly

### Notification Delivery
- **Foreground**: In-app notification + system notification
- **Background**: System notification with app icon
- **Closed**: FCM background delivery + local notification display

### User Experience
- **Recipients**: Get notifications based on their role and assignments
- **Different devices**: Each user gets unique FCM token
- **Same device**: FCM tokens cleared on logout to prevent conflicts

## 🔍 Troubleshooting

### Common Issues

#### 1. "Permission Denied" Error
```
Permission 'cloudmessaging.messages.create' denied
```
**Solution**: Add proper roles to service account (see step 2 above)

#### 2. "Failed to get access token" Error
**Solution**: 
- Verify JSON service account key is complete
- Check environment variable `FIREBASE_SERVICE_ACCOUNT_KEY` is set correctly
- Ensure private key format includes proper line breaks

#### 3. Notifications appear on wrong user
**Solution**: 
- Users testing on same device will share FCM token
- Use different devices for testing, or test with app closed
- Check console logs for "Same Token?" debug output

#### 4. Edge Function deployment fails
**Solution**:
```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy send-push-notification --debug
```

### Debug Logging
The app includes comprehensive logging for troubleshooting:

```
🔔 Creating notification: (notification creation)
📱 Recipient info: (token and user details)
📤 Sender info: (sender token comparison)
📨 Sending push notification: (FCM delivery)
✅ Push notification sent via edge function (success)
❌ Edge function failed: (errors)
```

## 📱 Testing

### Test Scenarios
1. **Same User Different Sessions**: Logout → Login → No cross-notifications
2. **Background Delivery**: Close app → Send notification → Should receive
3. **Role-Based Sending**: Admin sends to agent → Only agent receives
4. **Multiple Methods**: Edge function fails → Fallback to local notification

### Verification
- Check console logs for success/failure messages
- Verify notification appears in system tray
- Confirm notification stored in database
- Test with app in different states (foreground/background/closed)

## 🔐 Security Considerations

### Service Account Security
- Never commit service account JSON to version control
- Store securely in Supabase environment variables
- Rotate service account keys periodically

### User Privacy
- FCM tokens automatically cleared on logout
- Notifications only sent to intended recipients
- Database row-level security prevents unauthorized access

### App Permissions
- Request notification permissions gracefully
- Handle permission denials appropriately
- Respect user notification preferences

## 📈 Monitoring

### Success Metrics
- FCM delivery rates
- Notification open rates  
- User engagement with notifications
- Error rates and resolution times

### Log Monitoring
- Supabase Edge Function logs
- Firebase Cloud Messaging delivery reports
- App crash reports for notification-related issues

## 🔄 Updates and Maintenance

### Regular Tasks
- Monitor Firebase quota usage
- Update service account permissions as needed
- Review notification delivery success rates
- Update notification content and targeting

### Version Compatibility
- Test notifications after app updates
- Verify FCM SDK compatibility
- Update Edge Function dependencies as needed

---

## 📞 Support

For issues or questions about the notification system:
1. Check console logs for detailed error messages
2. Verify all setup steps completed correctly
3. Test with different devices/users for isolation
4. Review Firebase and Supabase dashboards for service status

## 🎉 Success Confirmation

When properly configured, you should see:
- ✅ "Push notification sent via edge function" in console logs
- ✅ Notifications delivered to correct recipients
- ✅ Background notifications working when app closed
- ✅ Proper app icon displayed in system notifications
- ✅ No cross-user notification conflicts