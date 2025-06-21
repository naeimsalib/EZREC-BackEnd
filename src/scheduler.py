#!/usr/bin/env python3
import time
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
import pytz

from .utils import logger, supabase, save_booking
from .config import (
    USER_ID,
    BOOKING_CHECK_INTERVAL,
    MIN_RECORDING_DURATION,
    MAX_RECORDING_DURATION
)

def get_next_booking() -> Optional[Dict[str, Any]]:
    """Get the next upcoming booking for the user."""
    try:
        # We need to use timezone-aware objects to correctly query the database
        now_utc = datetime.now(pytz.utc)
        
        # Query for bookings that are scheduled to start in the future but soon.
        # This gives us a window to prepare for the recording.
        # - 'start_time' must be greater than or equal to now.
        # - 'start_time' should be within a reasonable future window (e.g., next 24 hours)
        #   to avoid pulling bookings that are very far in the future.
        future_limit = now_utc + timedelta(days=1)

        response = (
            supabase.table("bookings")
            .select("*")
            .eq("user_id", USER_ID)
            .gte("start_time", now_utc.isoformat())
            .lte("start_time", future_limit.isoformat())
            .order("start_time", desc=False)
            .limit(1)
            .execute()
        )

        if response.data:
            booking = response.data[0]
            logger.info(f"Found upcoming booking: {booking['id']}")
            
            # The booking times from Supabase are in UTC (ISO 8601 format)
            start_utc = datetime.fromisoformat(booking["start_time"].replace("Z", "+00:00"))
            end_utc = datetime.fromisoformat(booking["end_time"].replace("Z", "+00:00"))
            duration = (end_utc - start_utc).total_seconds()

            if MIN_RECORDING_DURATION <= duration <= MAX_RECORDING_DURATION:
                return booking
            else:
                logger.warning(
                    f"Booking {booking['id']} duration ({duration}s) is outside the "
                    f"allowed range of {MIN_RECORDING_DURATION}-{MAX_RECORDING_DURATION}s."
                )
                return None
        
        return None

    except Exception as e:
        logger.error(f"Failed to get next booking: {e}", exc_info=True)
        return None

def main():
    """Main scheduler loop."""
    logger.info("Scheduler service started")
    last_booking_id = None
    
    while True:
        try:
            booking = get_next_booking()
            
            if booking and booking["id"] != last_booking_id:
                logger.info(f"New booking found: {booking}")
                if save_booking(booking):
                    last_booking_id = booking["id"]
                else:
                    logger.error("Failed to save booking information")
            
            time.sleep(BOOKING_CHECK_INTERVAL)
            
        except Exception as e:
            logger.error(f"Error in scheduler loop: {e}")
            time.sleep(5)  # Wait before retrying

if __name__ == "__main__":
    main() 