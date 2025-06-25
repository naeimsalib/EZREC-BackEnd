-- Migration 006: Create recordings table for EZREC
-- This table stores metadata about recorded videos

CREATE TABLE IF NOT EXISTS recordings (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    camera_id TEXT NOT NULL,
    booking_id TEXT,
    filename TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    file_hash TEXT NOT NULL,
    duration_seconds INTEGER,
    recording_date DATE NOT NULL,
    recording_time TIME NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'completed',
    metadata JSONB
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_recordings_user_id ON recordings(user_id);
CREATE INDEX IF NOT EXISTS idx_recordings_camera_id ON recordings(camera_id);
CREATE INDEX IF NOT EXISTS idx_recordings_booking_id ON recordings(booking_id);
CREATE INDEX IF NOT EXISTS idx_recordings_date ON recordings(recording_date);
CREATE INDEX IF NOT EXISTS idx_recordings_status ON recordings(status);
CREATE INDEX IF NOT EXISTS idx_recordings_created_at ON recordings(created_at);

-- Add a unique constraint on file_hash to prevent duplicates
ALTER TABLE recordings ADD CONSTRAINT unique_file_hash UNIQUE (file_hash);

-- Comments for documentation
COMMENT ON TABLE recordings IS 'Stores metadata about video recordings created by EZREC cameras';
COMMENT ON COLUMN recordings.id IS 'Unique identifier (typically file hash)';
COMMENT ON COLUMN recordings.booking_id IS 'Reference to the booking that triggered this recording';
COMMENT ON COLUMN recordings.file_hash IS 'MD5 hash of the video file for integrity checking';
COMMENT ON COLUMN recordings.metadata IS 'Additional recording metadata (resolution, fps, codec, etc.)';
COMMENT ON COLUMN recordings.status IS 'Recording status: completed, uploading, failed, etc.'; 