-- Check route places data
-- This will help diagnose why routes show 0 places

-- 1. Check all routes and their place counts
SELECT 
    r.id,
    r.name,
    r.status,
    r.created_at,
    COUNT(rp.id) as place_count
FROM routes r
LEFT JOIN route_places rp ON r.id = rp.route_id
GROUP BY r.id, r.name, r.status, r.created_at
ORDER BY r.created_at DESC;

-- 2. Check route_places table specifically
SELECT 
    rp.id,
    rp.route_id,
    rp.place_id,
    rp.visit_order,
    rp.created_at,
    r.name as route_name,
    p.name as place_name
FROM route_places rp
LEFT JOIN routes r ON rp.route_id = r.id
LEFT JOIN places p ON rp.place_id = p.id
ORDER BY rp.created_at DESC;

-- 3. Check if there are any route_places at all
SELECT COUNT(*) as total_route_places FROM route_places;

-- 4. Check specific route that shows 0 places (replace with actual route ID)
SELECT 
    rp.*,
    p.name as place_name
FROM route_places rp
LEFT JOIN places p ON rp.place_id = p.id
WHERE rp.route_id = 'YOUR_ROUTE_ID_HERE'
ORDER BY rp.visit_order;

-- 5. Test the Supabase query syntax
SELECT 
    r.*,
    json_agg(
        json_build_object(
            'id', rp.id,
            'place_id', rp.place_id,
            'visit_order', rp.visit_order
        )
    ) FILTER (WHERE rp.id IS NOT NULL) as route_places_data,
    COUNT(rp.id) as places_count
FROM routes r
LEFT JOIN route_places rp ON r.id = rp.route_id
GROUP BY r.id
ORDER BY r.created_at DESC;