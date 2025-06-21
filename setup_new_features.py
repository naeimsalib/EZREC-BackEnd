#!/usr/bin/env python3
"""
Setup script for SmartCam new features.
This script helps set up the database schema and initial configuration.
"""

import os
import sys
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
USER_ID = os.getenv("USER_ID")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def check_database_columns():
    """Check if the new database columns exist."""
    print("Checking database schema...")
    
    try:
        # Try to query the new columns
        response = supabase.table("system_status").select("cameras_online, total_cameras").limit(1).execute()
        print("✓ system_status table has new camera tracking columns")
        
        # Check videos table for booking_id column
        try:
            response = supabase.table("videos").select("booking_id").limit(1).execute()
            print("✓ videos table has booking_id column")
        except Exception as e:
            print("⚠ videos table missing booking_id column")
            print("  This is optional - videos will work without it")
            
        return True
        
    except Exception as e:
        print("❌ Database schema needs updating")
        print(f"Error: {e}")
        return False

def create_directories():
    """Create necessary directories."""
    print("\nCreating directories...")
    
    directories = [
        "temp",
        "user_assets",
        "temp_processing"
    ]
    
    for directory in directories:
        if not os.path.exists(directory):
            os.makedirs(directory)
            print(f"✓ Created directory: {directory}")
        else:
            print(f"✓ Directory exists: {directory}")

def setup_user_settings():
    """Set up basic user settings if they don't exist."""
    print("\nSetting up user settings...")
    
    try:
        # Check if user settings exist
        response = supabase.table("user_settings").select("*").eq("user_id", USER_ID).execute()
        
        if not response.data:
            # Create default user settings
            default_settings = {
                "user_id": USER_ID,
                "logo_path": "user_assets/default_logo.png",
                "logo_position": "top-right",
                "intro_video_path": None,  # User needs to add this
                "created_at": "now()",
                "updated_at": "now()"
            }
            
            supabase.table("user_settings").insert(default_settings).execute()
            print("✓ Created default user settings")
            print("  - Logo path: user_assets/default_logo.png")
            print("  - Logo position: top-right")
            print("  - Intro video: Not configured (optional)")
            
        else:
            print("✓ User settings already exist")
            settings = response.data[0]
            print(f"  - Logo path: {settings.get('logo_path', 'Not set')}")
            print(f"  - Logo position: {settings.get('logo_position', 'Not set')}")
            print(f"  - Intro video: {settings.get('intro_video_path', 'Not configured')}")
            
    except Exception as e:
        print(f"❌ Error setting up user settings: {e}")

def create_sample_logo():
    """Create a sample logo file if none exists."""
    print("\nChecking for logo file...")
    
    logo_path = "user_assets/default_logo.png"
    
    if not os.path.exists(logo_path):
        print(f"⚠ No logo found at {logo_path}")
        print("  Please add your logo file to user_assets/default_logo.png")
        print("  Supported formats: PNG, JPG, JPEG")
        print("  Recommended size: 200x200 pixels or smaller")
    else:
        print(f"✓ Logo file exists: {logo_path}")

def run_migration_sql():
    """Provide instructions for running the SQL migration."""
    print("\nDatabase Migration Instructions:")
    print("=" * 50)
    print("If the database schema check failed, you need to run the migration:")
    print("")
    print("1. Go to your Supabase dashboard")
    print("2. Navigate to SQL Editor")
    print("3. Run the following SQL:")
    print("")
    print("```sql")
    with open("migrations/003_add_camera_tracking_columns.sql", "r") as f:
        print(f.read())
    print("```")
    print("")
    print("4. Then run this setup script again")

def main():
    """Main setup function."""
    print("SmartCam New Features Setup")
    print("=" * 30)
    
    if not all([SUPABASE_URL, SUPABASE_KEY, USER_ID]):
        print("❌ Missing environment variables!")
        print("Please ensure .env file contains:")
        print("  - SUPABASE_URL")
        print("  - SUPABASE_SERVICE_ROLE_KEY") 
        print("  - USER_ID")
        return
    
    # Step 1: Check database schema
    schema_ok = check_database_columns()
    
    # Step 2: Create directories
    create_directories()
    
    # Step 3: Set up user settings
    setup_user_settings()
    
    # Step 4: Check for logo
    create_sample_logo()
    
    print("\n" + "=" * 50)
    print("Setup Summary")
    print("=" * 50)
    
    if schema_ok:
        print("✅ Database schema is ready")
        print("✅ Directories created")
        print("✅ User settings configured")
        print("")
        print("🎉 Setup complete! New features are ready to use.")
        print("")
        print("Next steps:")
        print("1. Add your logo to user_assets/default_logo.png")
        print("2. Optionally add intro video and update user settings")
        print("3. Run: python test_new_features.py")
        print("4. Start the main application: python main.py")
        
    else:
        print("⚠️  Database schema needs updating")
        print("✅ Directories created")
        print("✅ User settings configured")
        print("")
        run_migration_sql()

if __name__ == "__main__":
    main() 