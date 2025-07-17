# Live Map Touring Task Geofences Implementation

## Overview
This implementation adds touring task geofences to the live map screen, allowing administrators to visualize both campaign geofences and touring task geofences with different colors and filtering options.

## Database Changes

### New RPC Function: `get_all_geofences_wkt()`
Located in: `supabase/migrations/20250716_create_geofence_wkt_function.sql`

This function returns both campaign geofences and touring task geofences in WKT format:

```sql
CREATE OR REPLACE FUNCTION get_all_geofences_wkt()
RETURNS TABLE(
    geofence_id UUID,
    geofence_name TEXT,
    geofence_area_wkt TEXT,
    geofence_type TEXT,
    geofence_color TEXT,
    campaign_id UUID,
    campaign_name TEXT,
    touring_task_id UUID,
    touring_task_title TEXT,
    max_agents INTEGER,
    is_active BOOLEAN
) AS $$
```

**Returns:**
- **Campaign geofences**: Regular geofences with type 'campaign'
- **Touring task geofences**: Geofences that have touring tasks with type 'touring_task'

## Flutter Implementation Changes

### Enhanced GeofenceInfo Class
The `GeofenceInfo` class now includes:
- `type`: 'campaign' or 'touring_task'
- `color`: Parsed from hex color string
- `campaignId`, `campaignName`: Campaign information
- `touringTaskId`, `touringTaskTitle`: Touring task information
- `isActive`: Whether the geofence is active

### Visual Differentiation
- **Campaign geofences**: Default orange color, 2px stroke width
- **Touring task geofences**: Default purple color, 3px stroke width (thicker to stand out)
- **Custom colors**: Both types use colors from the database

### Enhanced Geofence Panel
The geofence panel now includes:
1. **Type filters**:
   - Campaign Geofences (with campaign icon)
   - Touring Task Geofences (with tour icon)
2. **Visual indicators**:
   - Different icons for each type
   - Color-coded icons matching the geofence color
   - Subtitle showing campaign name for context
3. **Filtering functionality**:
   - Toggle each type on/off
   - "Select All Visible" applies only to filtered results

### Key Methods Added/Modified

#### `GeofenceInfo.fromJson()`
- Parses database response into GeofenceInfo objects
- Handles color parsing from hex strings
- Includes WKT polygon parsing

#### `_updateGeofenceVisibility()`
- Updates visibility based on type filters
- Maintains proper checkbox states
- Removes invisible geofences from visible set

#### `_updatePolygons()`
- Uses individual geofence colors
- Applies different stroke widths based on type
- Maintains consistent opacity (15%)

## Usage

### For Administrators
1. Open the live map screen
2. Click the geofence panel button (layers icon)
3. Use type filters to show/hide:
   - Campaign Geofences (orange by default)
   - Touring Task Geofences (purple by default)
4. Individual geofences can be toggled on/off
5. Different visual styles help distinguish between types

### For Developers
The implementation is backward compatible:
- Existing campaign geofences continue to work
- New touring task geofences are added alongside
- Type filtering is optional (both enabled by default)

## Database Migration Required
The RPC function `get_all_geofences_wkt()` must be created in the database for this feature to work. The migration file is provided but needs to be applied to the database.

## Benefits
1. **Visual context**: See touring task locations on the map
2. **Better planning**: Understand spatial relationships between tasks
3. **Filtering options**: Focus on specific types of geofences
4. **Color coding**: Distinguish between campaign and touring task geofences
5. **Comprehensive view**: Single map shows all location-based work

## Technical Notes
- Geofence colors are stored as hex strings in the database
- WKT parsing handles standard PostGIS POLYGON format
- Error handling gracefully skips invalid geofences
- Memory efficient: only active geofences are loaded
- Real-time updates: Changes in database are reflected on next refresh