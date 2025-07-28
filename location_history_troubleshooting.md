# Location History Troubleshooting Guide

## Common Issues and Solutions

### 1. Table doesn't exist
If the `location_history` table doesn't exist, run the `create_location_history_table.sql` script.

### 2. Permission Issues (RLS)
Check if Row Level Security policies are blocking access:
```sql
-- Check current policies
SELECT * FROM pg_policies WHERE tablename = 'location_history';

-- Temporarily disable RLS for testing (CAUTION: Only for debugging)
ALTER TABLE location_history DISABLE ROW LEVEL SECURITY;
```

### 3. Missing Indexes
Poor performance might be due to missing indexes:
```sql
-- Check existing indexes
SELECT * FROM pg_indexes WHERE tablename = 'location_history';
```

### 4. Data Type Issues
Check if your app is sending data in the correct format:
```sql
-- Check for invalid data
SELECT * FROM location_history 
WHERE latitude NOT BETWEEN -90 AND 90 
   OR longitude NOT BETWEEN -180 AND 180;
```

### 5. App-Side Common Issues

#### Flutter/Dart Side:
```dart
// Check if LocationHistoryService is properly initialized
// In your LocationHistoryService, ensure:

Future<List<LocationHistory>> getLocationHistory({
  required String userId,
  DateTime? startDate,
  DateTime? endDate,
}) async {
  try {
    var query = supabase
        .from('location_history')
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: false);
    
    if (startDate != null) {
      query = query.gte('timestamp', startDate.toIso8601String());
    }
    
    if (endDate != null) {
      query = query.lte('timestamp', endDate.toIso8601String());
    }
    
    final response = await query;
    return response.map((json) => LocationHistory.fromJson(json)).toList();
  } catch (e) {
    print('Error fetching location history: $e');
    return [];
  }
}
```

### 6. Test Queries

#### Check if data exists:
```sql
SELECT COUNT(*) FROM location_history;
```

#### Check recent entries:
```sql
SELECT * FROM location_history 
ORDER BY created_at DESC 
LIMIT 10;
```

#### Check for specific user:
```sql
SELECT * FROM location_history 
WHERE user_id = 'YOUR_USER_ID'
ORDER BY timestamp DESC 
LIMIT 5;
```

### 7. Debug Location Service Issues

#### Check if location service is working:
```dart
// Add debug prints in your location service
class LocationService {
  Future<void> updateLocation(double lat, double lng) async {
    print('Updating location: $lat, $lng');
    
    try {
      await supabase.from('location_history').insert({
        'user_id': supabase.auth.currentUser?.id,
        'latitude': lat,
        'longitude': lng,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': 5.0,
      });
      print('Location updated successfully');
    } catch (e) {
      print('Error updating location: $e');
    }
  }
}
```

### 8. Common SQL Fixes

#### Reset RLS policies:
```sql
-- Drop all policies
DROP POLICY IF EXISTS "Users can view own location history" ON location_history;
DROP POLICY IF EXISTS "Users can insert own location history" ON location_history;
DROP POLICY IF EXISTS "Admins can view all location history" ON location_history;

-- Recreate basic policy
CREATE POLICY "Basic location access" ON location_history
    FOR ALL USING (true);
```

#### Add missing columns:
```sql
-- If your table is missing columns
ALTER TABLE location_history ADD COLUMN IF NOT EXISTS accuracy DOUBLE PRECISION;
ALTER TABLE location_history ADD COLUMN IF NOT EXISTS address TEXT;
```

### 9. Performance Optimization

#### Add better indexes:
```sql
-- For user-specific queries
CREATE INDEX IF NOT EXISTS idx_location_user_time ON location_history(user_id, timestamp DESC);

-- For spatial queries (if using PostGIS)
CREATE INDEX IF NOT EXISTS idx_location_spatial ON location_history USING GIST (ST_Point(longitude, latitude));
```

### 10. Data Cleanup

#### Remove old data:
```sql
-- Delete location data older than 30 days
DELETE FROM location_history 
WHERE created_at < NOW() - INTERVAL '30 days';
```

#### Remove duplicate entries:
```sql
-- Remove duplicate location entries
WITH duplicates AS (
  SELECT id, ROW_NUMBER() OVER (
    PARTITION BY user_id, latitude, longitude, timestamp 
    ORDER BY created_at
  ) as rn
  FROM location_history
)
DELETE FROM location_history 
WHERE id IN (
  SELECT id FROM duplicates WHERE rn > 1
);
```