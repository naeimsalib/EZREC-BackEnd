-- Migration to add camera tracking columns to system_status table
-- Run this if the columns don't exist yet

DO $$
BEGIN
    -- Add cameras_online column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'cameras_online'
    ) THEN
        ALTER TABLE system_status ADD COLUMN cameras_online INTEGER DEFAULT 0;
    END IF;
    
    -- Add total_cameras column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'total_cameras'
    ) THEN
        ALTER TABLE system_status ADD COLUMN total_cameras INTEGER DEFAULT 1;
    END IF;
    
    -- Add booking_id column to videos table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'videos' AND column_name = 'booking_id'
    ) THEN
        ALTER TABLE videos ADD COLUMN booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL;
    END IF;
    
END $$; 