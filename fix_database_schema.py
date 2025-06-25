#!/usr/bin/env python3
"""
EZREC Database Schema Fix Script
Fixes missing columns and creates the recordings table
"""

import sys
import os

# Add src directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

def main():
    print("EZREC Database Schema Fix")
    print("=" * 40)
    
    try:
        from utils import supabase
        
        if not supabase:
            print("❌ Failed to initialize Supabase client")
            return False
        
        print("✅ Supabase connection successful")
        
        # Step 1: Add camera_id column to bookings table
        print("\n📋 Step 1: Adding camera_id column to bookings table...")
        
        try:
            # Check if camera_id column exists
            result = supabase.table('bookings').select('camera_id').limit(1).execute()
            print("✅ camera_id column already exists in bookings table")
        except Exception as e:
            if "does not exist" in str(e) or "42703" in str(e):
                print("⚠️  camera_id column missing, adding it now...")
                
                # Add camera_id column using Supabase SQL
                sql_add_column = """
                ALTER TABLE bookings 
                ADD COLUMN IF NOT EXISTS camera_id TEXT;
                """
                
                try:
                    # Execute SQL to add column
                    supabase.rpc('exec_sql', {'sql': sql_add_column}).execute()
                    print("✅ camera_id column added to bookings table")
                except Exception as sql_e:
                    print(f"❌ Failed to add camera_id column via RPC: {sql_e}")
                    print("\n📝 Manual SQL needed:")
                    print("Please run this SQL in your Supabase SQL Editor:")
                    print(sql_add_column)
                    print("\nThen update existing bookings:")
                    print("UPDATE bookings SET camera_id = 'raspberry_pi_camera' WHERE camera_id IS NULL;")
                    return False
            else:
                print(f"❌ Unexpected error checking camera_id: {e}")
                return False
        
        # Step 2: Create recordings table
        print("\n🎬 Step 2: Creating recordings table...")
        
        # Read the SQL file
        sql_file = 'create_recordings_table.sql'
        if os.path.exists(sql_file):
            with open(sql_file, 'r') as f:
                create_table_sql = f.read()
            
            try:
                # Try to create table
                supabase.rpc('exec_sql', {'sql': create_table_sql}).execute()
                print("✅ Recordings table created successfully")
            except Exception as e:
                if "already exists" in str(e):
                    print("✅ Recordings table already exists")
                else:
                    print(f"❌ Failed to create recordings table via RPC: {e}")
                    print(f"\n📝 Manual SQL needed:")
                    print(f"Please run the SQL from {sql_file} in your Supabase SQL Editor")
                    return False
        else:
            print(f"❌ SQL file {sql_file} not found")
            return False
        
        # Step 3: Update existing bookings with default camera_id
        print("\n🔄 Step 3: Updating existing bookings with camera_id...")
        
        try:
            # Check for bookings without camera_id
            result = supabase.table('bookings').select('id').is_('camera_id', 'null').execute()
            
            if result.data:
                # Update bookings without camera_id
                update_result = supabase.table('bookings')\
                    .update({'camera_id': 'raspberry_pi_camera'})\
                    .is_('camera_id', 'null')\
                    .execute()
                
                print(f"✅ Updated {len(result.data)} bookings with camera_id")
            else:
                print("✅ All bookings already have camera_id set")
                
        except Exception as e:
            print(f"⚠️  Could not update existing bookings: {e}")
            print("You may need to manually update existing bookings:")
            print("UPDATE bookings SET camera_id = 'raspberry_pi_camera' WHERE camera_id IS NULL;")
        
        print("\n🎉 Database schema fix completed!")
        print("\nYou can now run the upload script:")
        print("sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 upload_recordings.py")
        
        return True
        
    except Exception as e:
        print(f"❌ Script failed: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 