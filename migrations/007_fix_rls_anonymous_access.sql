-- Migration 007: Fix RLS policies for anonymous access
-- This migration resolves the critical issue where EZREC system couldn't access bookings
-- due to Row Level Security policies requiring authenticated users
-- 
-- Problem: Original policy required auth.uid() = user_id, but EZREC uses anonymous API key
-- Solution: Allow anonymous access to bookings table for EZREC system functionality
--
-- Date: 2025-06-25
-- Issue: EZREC orchestrator returning 0 results despite bookings existing

-- Drop the existing restrictive policy that blocks anonymous access
DROP POLICY IF EXISTS "Users can access their own bookings" ON bookings;

-- Create a new policy that allows anonymous read access
-- This enables the EZREC system to read bookings using the anonymous API key
CREATE POLICY "Allow anonymous read access to bookings" 
ON bookings FOR SELECT 
TO public 
USING (true);

-- Allow anonymous write access for booking creation and updates
-- This enables the EZREC system to create and modify bookings
CREATE POLICY "Allow anonymous write access to bookings" 
ON bookings FOR ALL 
TO public 
USING (true);

-- Log the fix
INSERT INTO schema_migrations (version, applied_at) 
VALUES ('007_fix_rls_anonymous_access', NOW())
ON CONFLICT (version) DO NOTHING; 