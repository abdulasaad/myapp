# Debug Geofences - Check Data

## Step 1: Check if geofences have valid polygon data

```sql
SELECT * FROM get_all_geofences_wkt();
```

## Step 2: Check campaign geofences table directly

```sql
SELECT id, name, area_text, color, is_active 
FROM campaign_geofences 
WHERE is_active = true;
```

## Step 3: Check if area_text contains valid WKT data

```sql
SELECT id, name, 
       CASE 
           WHEN area_text IS NULL THEN 'NULL'
           WHEN area_text = '' THEN 'EMPTY'
           WHEN area_text LIKE 'POLYGON%' THEN 'VALID WKT'
           ELSE 'INVALID FORMAT'
       END as area_status,
       area_text
FROM campaign_geofences 
WHERE is_active = true;
```