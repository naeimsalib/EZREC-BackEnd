-- Migration to add camera_id columns to system_status and bookings tables
-- This fixes the "column does not exist" errors in the EZREC backend

DO $$
BEGIN
    -- Add camera_id column to system_status table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'camera_id'
    ) THEN
        ALTER TABLE system_status ADD COLUMN camera_id TEXT DEFAULT '0';
        RAISE NOTICE 'Added camera_id column to system_status table';
    ELSE
        RAISE NOTICE 'camera_id column already exists in system_status table';
    END IF;
    
    -- Add camera_id column to bookings table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'camera_id'
    ) THEN
        ALTER TABLE bookings ADD COLUMN camera_id TEXT DEFAULT '0';
        RAISE NOTICE 'Added camera_id column to bookings table';
    ELSE
        RAISE NOTICE 'camera_id column already exists in bookings table';
    END IF;
    
END $$;

-- Optional: Update existing records to have camera_id = '0' if they are NULL
UPDATE system_status SET camera_id = '0' WHERE camera_id IS NULL;
UPDATE bookings SET camera_id = '0' WHERE camera_id IS NULL; 