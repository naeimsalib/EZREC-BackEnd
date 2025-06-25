-- Create recordings table for EZREC system
-- This table stores metadata about recorded videos

CREATE TABLE IF NOT EXISTS recordings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    camera_id TEXT NOT NULL,
    booking_id TEXT,
    filename TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT NOT NULL DEFAULT 0,
    duration_seconds INTEGER,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    recording_date DATE NOT NULL,
    status TEXT DEFAULT 'completed' CHECK (status IN ('recording', 'completed', 'failed', 'uploaded')),
    format TEXT DEFAULT 'mp4',
    resolution TEXT,
    fps INTEGER,
    file_hash TEXT, -- MD5 hash for integrity checking
    upload_status TEXT DEFAULT 'local' CHECK (upload_status IN ('local', 'uploading', 'uploaded', 'failed')),
    upload_url TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_recordings_user_id ON recordings(user_id);
CREATE INDEX IF NOT EXISTS idx_recordings_camera_id ON recordings(camera_id);
CREATE INDEX IF NOT EXISTS idx_recordings_booking_id ON recordings(booking_id);
CREATE INDEX IF NOT EXISTS idx_recordings_recording_date ON recordings(recording_date);
CREATE INDEX IF NOT EXISTS idx_recordings_status ON recordings(status);
CREATE INDEX IF NOT EXISTS idx_recordings_created_at ON recordings(created_at);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_recordings_updated_at 
    BEFORE UPDATE ON recordings 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security (RLS)
ALTER TABLE recordings ENABLE ROW LEVEL SECURITY;

-- Create policy for users to only see their own recordings
CREATE POLICY "Users can view their own recordings" ON recordings
    FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert their own recordings" ON recordings
    FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update their own recordings" ON recordings
    FOR UPDATE USING (auth.uid()::text = user_id);

-- Grant necessary permissions
GRANT ALL ON recordings TO authenticated;
GRANT ALL ON recordings TO service_role; 