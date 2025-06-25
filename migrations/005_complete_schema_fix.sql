-- Complete schema fix for EZREC Backend
-- Adds all missing columns to make the backend fully functional

DO $$
BEGIN
    -- Fix bookings table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'camera_id'
    ) THEN
        ALTER TABLE bookings ADD COLUMN camera_id TEXT DEFAULT '0';
        RAISE NOTICE 'Added camera_id column to bookings table';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'status'
    ) THEN
        ALTER TABLE bookings ADD COLUMN status TEXT DEFAULT 'confirmed';
        RAISE NOTICE 'Added status column to bookings table';
    END IF;
    
    -- Fix system_status table with all system metrics columns
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'camera_id'
    ) THEN
        ALTER TABLE system_status ADD COLUMN camera_id TEXT DEFAULT '0';
        RAISE NOTICE 'Added camera_id column to system_status table';
    END IF;
    
    -- CPU metrics
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'cpu_count'
    ) THEN
        ALTER TABLE system_status ADD COLUMN cpu_count INTEGER DEFAULT 4;
        RAISE NOTICE 'Added cpu_count column to system_status table';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'cpu_usage_percent'
    ) THEN
        ALTER TABLE system_status ADD COLUMN cpu_usage_percent FLOAT DEFAULT 0.0;
        RAISE NOTICE 'Added cpu_usage_percent column to system_status table';
    END IF;
    
    -- Memory metrics
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'memory_usage_percent'
    ) THEN
        ALTER TABLE system_status ADD COLUMN memory_usage_percent FLOAT DEFAULT 0.0;
        RAISE NOTICE 'Added memory_usage_percent column to system_status table';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'memory_total_gb'
    ) THEN
        ALTER TABLE system_status ADD COLUMN memory_total_gb FLOAT DEFAULT 0.0;
        RAISE NOTICE 'Added memory_total_gb column to system_status table';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'memory_available_gb'
    ) THEN
        ALTER TABLE system_status ADD COLUMN memory_available_gb FLOAT DEFAULT 0.0;
        RAISE NOTICE 'Added memory_available_gb column to system_status table';
    END IF;
    
    -- Disk metrics
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'disk_usage_percent'
    ) THEN
        ALTER TABLE system_status ADD COLUMN disk_usage_percent FLOAT DEFAULT 0.0;
        RAISE NOTICE 'Added disk_usage_percent column to system_status table';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'disk_total_gb'
    ) THEN
        ALTER TABLE system_status ADD COLUMN disk_total_gb FLOAT DEFAULT 0.0;
        RAISE NOTICE 'Added disk_total_gb column to system_status table';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'disk_free_gb'
    ) THEN
        ALTER TABLE system_status ADD COLUMN disk_free_gb FLOAT DEFAULT 0.0;
        RAISE NOTICE 'Added disk_free_gb column to system_status table';
    END IF;
    
    -- System info
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'uptime_seconds'
    ) THEN
        ALTER TABLE system_status ADD COLUMN uptime_seconds INTEGER DEFAULT 0;
        RAISE NOTICE 'Added uptime_seconds column to system_status table';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'active_processes'
    ) THEN
        ALTER TABLE system_status ADD COLUMN active_processes INTEGER DEFAULT 0;
        RAISE NOTICE 'Added active_processes column to system_status table';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'temperature_celsius'
    ) THEN
        ALTER TABLE system_status ADD COLUMN temperature_celsius FLOAT DEFAULT 0.0;
        RAISE NOTICE 'Added temperature_celsius column to system_status table';
    END IF;
    
    -- Recording status
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'recording_errors'
    ) THEN
        ALTER TABLE system_status ADD COLUMN recording_errors INTEGER DEFAULT 0;
        RAISE NOTICE 'Added recording_errors column to system_status table';
    END IF;
    
    -- Storage info
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'storage_used'
    ) THEN
        ALTER TABLE system_status ADD COLUMN storage_used INTEGER DEFAULT 0;
        RAISE NOTICE 'Added storage_used column to system_status table';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'last_backup'
    ) THEN
        ALTER TABLE system_status ADD COLUMN last_backup TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE 'Added last_backup column to system_status table';
    END IF;
    
    -- Network metrics (stored as JSONB for flexibility)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_status' AND column_name = 'network_io'
    ) THEN
        ALTER TABLE system_status ADD COLUMN network_io JSONB DEFAULT '{}';
        RAISE NOTICE 'Added network_io column to system_status table';
    END IF;
    
END $$;

-- Update existing records to have default values where NULL
UPDATE system_status SET 
    camera_id = '0' WHERE camera_id IS NULL,
    cpu_count = 4 WHERE cpu_count IS NULL,
    cpu_usage_percent = 0.0 WHERE cpu_usage_percent IS NULL,
    memory_usage_percent = 0.0 WHERE memory_usage_percent IS NULL,
    memory_total_gb = 0.0 WHERE memory_total_gb IS NULL,
    memory_available_gb = 0.0 WHERE memory_available_gb IS NULL,
    disk_usage_percent = 0.0 WHERE disk_usage_percent IS NULL,
    disk_total_gb = 0.0 WHERE disk_total_gb IS NULL,
    disk_free_gb = 0.0 WHERE disk_free_gb IS NULL,
    uptime_seconds = 0 WHERE uptime_seconds IS NULL,
    active_processes = 0 WHERE active_processes IS NULL,
    temperature_celsius = 0.0 WHERE temperature_celsius IS NULL,
    recording_errors = 0 WHERE recording_errors IS NULL,
    storage_used = 0 WHERE storage_used IS NULL,
    network_io = '{}' WHERE network_io IS NULL;

UPDATE bookings SET 
    camera_id = '0' WHERE camera_id IS NULL,
    status = 'confirmed' WHERE status IS NULL; 