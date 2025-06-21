-- Migration to fix system_status table constraints and optionally add booking_id to videos table
-- Run this in your Supabase SQL editor

-- 1. First, clean up any duplicate system_status entries (using created_at instead of MIN(id))
DELETE FROM system_status 
WHERE created_at NOT IN (
    SELECT MAX(created_at) 
    FROM system_status 
    GROUP BY user_id
);

-- 2. Add unique constraint on user_id to prevent duplicates
ALTER TABLE system_status 
ADD CONSTRAINT system_status_user_id_unique UNIQUE (user_id);

-- 3. Optional: Add booking_id column to videos table (uncomment if needed)
-- ALTER TABLE videos 
-- ADD COLUMN booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL;

-- 4. Create index for better performance
CREATE INDEX IF NOT EXISTS idx_system_status_user_id ON system_status(user_id);
CREATE INDEX IF NOT EXISTS idx_system_status_last_seen ON system_status(last_seen);

-- 5. Verify the constraint was added
SELECT constraint_name, constraint_type 
FROM information_schema.table_constraints 
WHERE table_name = 'system_status' AND constraint_type = 'UNIQUE';

-- Verify the changes
SELECT 'Migration completed successfully' as status; 