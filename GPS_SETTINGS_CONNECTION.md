# GPS Settings Connection and Effects

## Available GPS Settings (Configured by Admin)

### 1. **gps_ping_interval** (Default: 30 seconds)
- **Description**: How often location updates are sent
- **Used in**: `BackgroundLocationService.startLocationTracking()`
- **Effect**: Controls the Timer interval for periodic location updates
- **Connection**: ✅ WORKING - Line 245 retrieves this setting

### 2. **gps_accuracy_level** (Default: 'medium')
- **Description**: GPS accuracy mode (low/medium/high/best)
- **Used in**: `BackgroundLocationService.fetchAndSendLocation()`
- **Effect**: Sets Geolocator's desiredAccuracy parameter
- **Connection**: ✅ WORKING - Line 178 retrieves, Line 183 applies

### 3. **gps_timeout** (Default: 30 seconds)
- **Description**: Maximum time to wait for GPS location
- **Used in**: `BackgroundLocationService.fetchAndSendLocation()`
- **Effect**: Sets timeLimit for getCurrentPosition()
- **Connection**: ✅ WORKING - Line 179 retrieves, Line 184 applies

### 4. **background_accuracy_threshold** (Default: 100 meters)
- **Description**: Maximum acceptable accuracy for background updates
- **Used in**: `BackgroundLocationService.fetchAndSendLocation()`
- **Effect**: Filters out inaccurate location readings
- **Connection**: ✅ WORKING - Line 188 retrieves, Line 189 filters

### 5. **gps_accuracy_threshold** (Default: 75 meters)
- **Description**: Maximum acceptable accuracy for foreground updates
- **Used in**: Not currently used in the code
- **Effect**: Should filter foreground location updates
- **Connection**: ❌ NOT CONNECTED

### 6. **gps_distance_filter** (Default: 10 meters)
- **Description**: Minimum distance change before sending update
- **Used in**: Not currently used in the code
- **Effect**: Should prevent updates when stationary
- **Connection**: ❌ NOT CONNECTED

### 7. **gps_speed_threshold** (Default: 1.0 m/s)
- **Description**: Minimum speed to consider device moving
- **Used in**: Not currently used in the code
- **Effect**: Should affect movement detection
- **Connection**: ❌ NOT CONNECTED

### 8. **gps_angle_threshold** (Default: 15 degrees)
- **Description**: Minimum heading change threshold
- **Used in**: Not currently used in the code
- **Effect**: Should filter heading changes
- **Connection**: ❌ NOT CONNECTED

## How Settings Flow Works

1. **Admin configures settings** in GPS Settings Screen
2. **Settings stored** in `app_settings` table in Supabase
3. **Background service retrieves** settings using `getSettingValue()`
4. **Settings applied** to Geolocator configuration
5. **Location updates** follow the configured parameters

## Currently Working Settings

✅ **Ping Interval**: Controls how often updates are sent (every X seconds)
✅ **Accuracy Level**: Controls GPS precision (low/medium/high/best)
✅ **Timeout**: Controls how long to wait for GPS fix
✅ **Background Accuracy Threshold**: Filters out inaccurate readings

## Settings That Need Implementation

❌ **GPS Accuracy Threshold**: Should be used in foreground LocationService
❌ **Distance Filter**: Should prevent updates when device is stationary
❌ **Speed Threshold**: Should be used for movement detection
❌ **Angle Threshold**: Should filter minor heading changes

## Recommendations

1. Implement distance filter in LocationService to reduce battery usage
2. Use speed threshold in SmartLocationManager for movement detection
3. Apply GPS accuracy threshold in foreground tracking
4. Consider angle threshold for vehicle tracking scenarios