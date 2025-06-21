# Emulator Location Setup for Testing

## Problem
Emulators often have issues with location services, which can cause the app to crash when requesting location permissions.

## Solution: Enable Mock Location in Emulator

### Option 1: Set Location via Emulator Controls
1. **Open Android Emulator**
2. **Click the "..." button** (extended controls) on the emulator toolbar
3. **Go to "Location" tab**
4. **Set a mock location**:
   - Latitude: `37.4219999` (Example: Google HQ)
   - Longitude: `-122.0840575`
   - Click "Send"

### Option 2: Set Location via ADB Command
```bash
# Set location via ADB (replace with your desired coordinates)
adb emu geo fix -122.0840575 37.4219999

# Alternative method
adb shell am start -a android.location.GPS_ENABLED_CHANGE --ez state true
```

### Option 3: Use Google Maps in Emulator
1. Open Google Maps in the emulator
2. Allow location permissions
3. This will initialize location services properly

## For Testing Al-Tijwal App:

### Install and Test:
```bash
# Install the debug APK
adb install build/app/outputs/flutter-apk/app-debug.apk

# Monitor logs while testing
adb logcat | grep -E "(flutter|LocationService|Geolocator)"
```

### Expected Behavior:
1. **Login as agent**
2. **Grant location permissions** when prompted
3. **Check logs** for location tracking messages:
   - "Location service enabled: true"
   - "Current location permission: granted"
   - "Attempting to get current location..."
   - "Location obtained: lat, lng (accuracy: Xm)"

### If Still Crashing:
1. **Check emulator location is enabled**:
   - Settings > Location > Use location (ON)
   - Settings > Apps > App Permissions > Location > Your App (Allowed)

2. **Try a different emulator**:
   - Use a newer Android version (API 29+)
   - Use an emulator with Google Play Services

3. **Test on real device** instead of emulator for more reliable results

## Debug APK Location:
```
build/app/outputs/flutter-apk/app-debug.apk
```

This debug version has enhanced logging to help identify location-related issues.