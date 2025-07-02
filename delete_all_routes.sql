-- Delete all routes and related data
-- Run these commands in order to avoid foreign key constraint violations

-- 1. First delete evidence files linked to place visits
DELETE FROM evidence 
WHERE place_visit_id IN (
    SELECT id FROM place_visits 
    WHERE route_assignment_id IN (
        SELECT id FROM route_assignments
    )
);

-- 2. Delete place visits
DELETE FROM place_visits 
WHERE route_assignment_id IN (
    SELECT id FROM route_assignments
);

-- 3. Delete route assignments
DELETE FROM route_assignments;

-- 4. Delete route places (places assigned to routes)
DELETE FROM route_places;

-- 5. Finally delete the routes themselves
DELETE FROM routes;

-- Optional: Reset the sequences if you want IDs to start fresh
-- This is PostgreSQL specific syntax
-- ALTER SEQUENCE routes_id_seq RESTART WITH 1;
-- ALTER SEQUENCE route_assignments_id_seq RESTART WITH 1;
-- ALTER SEQUENCE route_places_id_seq RESTART WITH 1;
-- ALTER SEQUENCE place_visits_id_seq RESTART WITH 1;

-- Verify deletion
SELECT 'Routes remaining:' as check_type, COUNT(*) as count FROM routes
UNION ALL
SELECT 'Route assignments remaining:', COUNT(*) FROM route_assignments
UNION ALL
SELECT 'Route places remaining:', COUNT(*) FROM route_places
UNION ALL
SELECT 'Place visits remaining:', COUNT(*) FROM place_visits
UNION ALL
SELECT 'Evidence files remaining:', COUNT(*) FROM evidence WHERE place_visit_id IS NOT NULL;