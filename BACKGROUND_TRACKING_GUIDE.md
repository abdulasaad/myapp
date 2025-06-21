# Background Location Tracking Guide

## ✅ New APK Features

The updated APK now includes **full background location tracking** that works when:
- App is minimized
- Phone is locked
- App is in background

## 📱 What You'll See

### When Starting Location Tracking:
1. **Location Permission**: Grant "While using app" or "All the time"
2. **Background Location Permission**: Grant "Allow all the time" 
3. **Notification Permission**: Grant to show background service notification
4. **Persistent Notification**: "Al-Tijwal Location Service" will appear

### Expected Behavior:
- **Foreground**: Location updates every 10 seconds when app is active
- **Background**: Location updates every 30 seconds when app is minimized/locked
- **Notification**: Shows "Al-Tijwal Location Service" with last update time
- **Database**: All location data continues to flow to Supabase

## 🔧 Testing Steps

1. **Install new APK**:
   ```
   build/app/outputs/flutter-apk/app-release.apk
   ```

2. **Login as agent** and grant all permissions

3. **Test foreground tracking**:
   - Check database for location updates every ~10 seconds
   - Monitor agent status in admin panel

4. **Test background tracking**:
   - Minimize the app or lock phone
   - You should see persistent notification
   - Check database for continued location updates every ~30 seconds
   - Agent status should remain active in admin panel

## 🎯 Key Improvements

### Dual Tracking System:
- **High frequency** (10s) when app is active
- **Battery optimized** (30s) when backgrounded

### Robust Permission Handling:
- Requests location, background location, and notification permissions
- Graceful fallback if some permissions denied
- Detailed logging for debugging

### Persistent Background Service:
- Foreground service with notification (required by Android)
- Survives app minimization and phone lock
- Automatic restart if killed by system

## 🔍 Troubleshooting

If background tracking doesn't work:

1. **Check notification**: Should see "Al-Tijwal Location Service"
2. **Check permissions**: Settings > Apps > Al-Tijwal > Permissions
3. **Check battery optimization**: Ensure app isn't battery optimized
4. **Check database**: Look for continued location updates in `location_history` table

## 📊 Monitoring

To monitor if it's working:
- Watch for persistent notification
- Check admin panel for agent status
- Monitor database location updates
- Agent should show as active even when phone is locked