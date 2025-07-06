# Firebase Cloud Messaging Setup Guide

## Current Status
The notification system is currently implemented with **in-app notifications only** using the `SimpleNotificationService`. To enable background/system push notifications, Firebase Cloud Messaging (FCM) needs to be properly configured.

## Required Steps for FCM Implementation

### 1. Firebase Project Setup
1. Create a new Firebase project at https://console.firebase.google.com/
2. Add Android app to the project with package name: `com.example.myapp`
3. Download the `google-services.json` file
4. Replace the placeholder file at `android/app/google-services.json`

### 2. Android Configuration
Update `android/app/build.gradle`:
```gradle
dependencies {
    implementation 'com.google.firebase:firebase-messaging:23.0.0'
    // ... other dependencies
}

apply plugin: 'com.google.gms.google-services'
```

Add to `android/build.gradle`:
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
    // ... other dependencies
}
```

### 3. Permissions & Manifest
Update `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

<application>
    <!-- FCM Service -->
    <service
        android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService"
        android:exported="false">
        <intent-filter>
            <action android:name="com.google.firebase.MESSAGING_EVENT" />
        </intent-filter>
    </service>
    
    <!-- Notification icon -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_icon"
        android:resource="@drawable/ic_notification" />
    
    <!-- Notification color -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_color"
        android:resource="@color/notification_color" />
</application>
```

### 4. Switch to Full NotificationService
1. Replace `SimpleNotificationService` imports with `NotificationService`
2. Ensure Firebase packages are properly installed
3. Test FCM functionality

### 5. Supabase Integration
Create the Supabase Edge Function for sending push notifications:

```typescript
// supabase/functions/send-notification/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  try {
    const { recipient_id, title, message, data } = await req.json()
    
    // Get user's FCM token from profiles table
    const { data: user } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('id', recipient_id)
      .single()
    
    if (user?.fcm_token) {
      // Send FCM notification
      const response = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Authorization': `key=${Deno.env.get('FCM_SERVER_KEY')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: user.fcm_token,
          notification: { title, body: message },
          data: data || {},
        }),
      })
      
      return new Response(JSON.stringify({ success: true }))
    }
    
    return new Response(JSON.stringify({ success: false, error: 'No FCM token' }))
  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error.message }))
  }
})
```

### 6. Database Triggers Enhancement
Update the notification triggers to call the Edge Function:

```sql
-- Add to notification triggers
SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/send-notification',
    headers := '{"Authorization": "Bearer YOUR_ANON_KEY", "Content-Type": "application/json"}',
    body := jsonb_build_object(
        'recipient_id', NEW.recipient_id,
        'title', NEW.title,
        'message', NEW.message,
        'data', NEW.data
    )
);
```

## Files Modified for Simple Implementation
- `lib/services/simple_notification_service.dart` - Simplified notification service
- `lib/main.dart` - Uses SimpleNotificationService
- `lib/screens/modern_home_screen.dart` - Updated notification integration
- `lib/screens/agent/notifications_screen.dart` - Complete notification UI

## Database Schema Created
- `notifications` table with proper RLS policies
- Notification management functions
- Database triggers for automatic notification creation

## Current Features Working
✅ In-app notification display
✅ Notification list screen with filtering
✅ Real-time notification count badge
✅ Mark as read functionality
✅ Database triggers for automatic notifications
✅ Notification navigation integration

## Next Steps for FCM
1. Complete Firebase project setup
2. Test FCM tokens and message delivery
3. Switch to full NotificationService
4. Implement Supabase Edge Function
5. Test background notifications