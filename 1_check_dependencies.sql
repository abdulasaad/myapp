SELECT table_name, table_schema 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('campaigns', 'campaign_geofences', 'profiles');