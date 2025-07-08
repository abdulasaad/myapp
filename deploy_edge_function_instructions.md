# Deploy Edge Function Instructions

## Quick Fix for Background Notifications

The app currently falls back to local notifications because the edge function is not deployed. To enable true background push notifications, follow these steps:

### Option 1: Deploy Edge Function (Recommended)

1. **Login to Supabase CLI:**
   ```bash
   supabase login
   ```

2. **Deploy the function:**
   ```bash
   supabase functions deploy send-push-notification
   ```

3. **Set FCM Server Key:**
   - Go to Firebase Console → Project Settings → Cloud Messaging
   - Copy the Server Key
   - In Supabase Dashboard → Project Settings → Edge Functions
   - Add environment variable: `FCM_SERVER_KEY` = `your-server-key`

### Option 2: Manual Deployment via Supabase Dashboard

1. Go to Supabase Dashboard → Edge Functions
2. Click "Create a new function" 
3. Name: `send-push-notification`
4. Copy the content from `supabase/functions/send-push-notification/index.ts`
5. Deploy the function
6. Add `FCM_SERVER_KEY` environment variable

### Option 3: Test Current Implementation

The current code will:
1. Try edge function (will fail with 404)
2. Try direct FCM (will fail - needs server key)
3. Fall back to local notification (works on current device only)

### What's Working Now:
- ✅ Database notifications (in-app polling works)
- ✅ Local notifications when app is open
- ✅ Background location service (with minimal notification)
- ❌ Background push notifications when app is closed

### To Test:
1. Send notification from admin
2. Check logs for "Method 3: Showing local notification as fallback"
3. This confirms the notification system is working, just using fallback method

### Background Behavior:
- When app is open: Notifications work via local fallback
- When app is closed: Must deploy edge function for true push notifications
- In-app notifications: Always work via database polling