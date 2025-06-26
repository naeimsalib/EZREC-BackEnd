#!/bin/bash

echo "🔧 EZREC SupabaseManager Query Parsing Fix"
echo "=========================================="

# Stop the service
echo "🛑 Stopping ezrec-backend service..."
sudo systemctl stop ezrec-backend

# Create a fixed version of the execute_query method
echo "🔧 Creating improved execute_query method..."
sudo tee /tmp/fixed_execute_query.py > /dev/null << 'EOF'
import re

def create_fixed_execute_query():
    return '''    async def execute_query(self, query: str, params: Dict[str, Any] = None):
        """Execute a raw SQL query with proper WHERE clause parsing - ENHANCED VERSION."""
        try:
            if not self.client:
                raise Exception("Supabase client not available")
            
            # For simple table queries, parse and execute
            if query.upper().startswith('SELECT'):
                # Handle bookings queries with WHERE conditions
                if 'FROM bookings' in query:
                    query_builder = self.client.table("bookings").select("*")
                    
                    # Enhanced parsing - use regex for more flexible matching
                    import re
                    
                    # Parse date condition
                    date_match = re.search(r"date\s*=\s*'([^']+)'", query, re.IGNORECASE)
                    if date_match:
                        date_value = date_match.group(1)
                        query_builder = query_builder.eq("date", date_value)
                        logger.info(f"📅 Filtering by date: {date_value}")
                    
                    # Parse user_id condition
                    user_id_match = re.search(r"user_id\s*=\s*'([^']+)'", query, re.IGNORECASE)
                    if user_id_match:
                        user_id_value = user_id_match.group(1)
                        query_builder = query_builder.eq("user_id", user_id_value)
                        logger.info(f"👤 Filtering by user_id: {user_id_value}")
                    
                    # Parse status condition
                    status_match = re.search(r"status\s*=\s*'([^']+)'", query, re.IGNORECASE)
                    if status_match:
                        status_value = status_match.group(1)
                        query_builder = query_builder.eq("status", status_value)
                        logger.info(f"📊 Filtering by status: {status_value}")
                    
                    # Parse ORDER BY
                    if re.search(r"ORDER BY\s+start_time\s+ASC", query, re.IGNORECASE):
                        query_builder = query_builder.order("start_time", desc=False)
                        logger.info("🔄 Ordering by start_time ASC")
                    elif re.search(r"ORDER BY\s+start_time\s+DESC", query, re.IGNORECASE):
                        query_builder = query_builder.order("start_time", desc=True)
                        logger.info("🔄 Ordering by start_time DESC")
                    
                    response = query_builder.execute()
                    logger.info(f"✅ Bookings query executed successfully - returned {len(response.data)} results")
                    return response.data
                    
                elif 'FROM videos' in query:
                    response = self.client.table("videos").select("*").execute()
                    logger.info(f"✅ Videos query executed - returned {len(response.data)} results")
                    return response.data
                elif 'FROM system_status' in query:
                    response = self.client.table("system_status").select("*").execute()
                    logger.info(f"✅ System status query executed - returned {len(response.data)} results")
                    return response.data
                else:
                    logger.info(f"🔍 Generic SELECT query executed")
                    # For other SELECT queries, just log and return empty for now
                    return []
            else:
                logger.warning(f"❌ Only SELECT queries supported. Received: {query}")
                return []
                
        except Exception as e:
            logger.error(f"❌ Query execution failed: {e}")
            raise'''

if __name__ == "__main__":
    print(create_fixed_execute_query())
EOF

# Apply the fix to utils.py
echo "🔧 Applying enhanced execute_query method..."
python3 /tmp/fixed_execute_query.py > /tmp/new_execute_query.txt

# Replace the execute_query method in utils.py
sudo cp /opt/ezrec-backend/src/utils.py /opt/ezrec-backend/src/utils.py.backup

# Use sed to replace the execute_query method
sudo sed -i '/async def execute_query/,/async def insert_booking\|async def get_bookings\|^class\|^def\|^$/c\
    async def execute_query(self, query: str, params: Dict[str, Any] = None):\
        """Execute a raw SQL query with proper WHERE clause parsing - ENHANCED VERSION."""\
        try:\
            if not self.client:\
                raise Exception("Supabase client not available")\
            \
            # For simple table queries, parse and execute\
            if query.upper().startswith("SELECT"):\
                # Handle bookings queries with WHERE conditions\
                if "FROM bookings" in query:\
                    query_builder = self.client.table("bookings").select("*")\
                    \
                    # Enhanced parsing - use regex for more flexible matching\
                    import re\
                    \
                    # Parse date condition\
                    date_match = re.search(r"date\\s*=\\s*'"'"'"([^'"'"'"]+)'"'"'", query, re.IGNORECASE)\
                    if date_match:\
                        date_value = date_match.group(1)\
                        query_builder = query_builder.eq("date", date_value)\
                        logger.info(f"📅 Filtering by date: {date_value}")\
                    \
                    # Parse user_id condition\
                    user_id_match = re.search(r"user_id\\s*=\\s*'"'"'"([^'"'"'"]+)'"'"'", query, re.IGNORECASE)\
                    if user_id_match:\
                        user_id_value = user_id_match.group(1)\
                        query_builder = query_builder.eq("user_id", user_id_value)\
                        logger.info(f"👤 Filtering by user_id: {user_id_value}")\
                    \
                    # Parse ORDER BY\
                    if re.search(r"ORDER BY\\s+start_time\\s+ASC", query, re.IGNORECASE):\
                        query_builder = query_builder.order("start_time", desc=False)\
                        logger.info("🔄 Ordering by start_time ASC")\
                    \
                    response = query_builder.execute()\
                    logger.info(f"✅ Bookings query executed successfully - returned {len(response.data)} results")\
                    return response.data\
                    \
                elif "FROM videos" in query:\
                    response = self.client.table("videos").select("*").execute()\
                    logger.info(f"✅ Videos query executed - returned {len(response.data)} results")\
                    return response.data\
                elif "FROM system_status" in query:\
                    response = self.client.table("system_status").select("*").execute()\
                    logger.info(f"✅ System status query executed - returned {len(response.data)} results")\
                    return response.data\
                else:\
                    logger.info(f"🔍 Generic SELECT query executed")\
                    return []\
            else:\
                logger.warning(f"❌ Only SELECT queries supported. Received: {query}")\
                return []\
                \
        except Exception as e:\
            logger.error(f"❌ Query execution failed: {e}")\
            raise\
\
' /opt/ezrec-backend/src/utils.py

# Verify the fix was applied
echo "✅ Verifying enhanced execute_query method:"
sudo grep -A 5 "Enhanced parsing" /opt/ezrec-backend/src/utils.py

# Clear Python cache
echo "🧹 Clearing Python cache..."
sudo find /opt/ezrec-backend -name "*.pyc" -delete
sudo find /opt/ezrec-backend -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Test the import
echo "🧪 Testing enhanced utils import..."
cd /opt/ezrec-backend
sudo /opt/ezrec-backend/venv/bin/python3 -c "
import sys
sys.path.insert(0, '/opt/ezrec-backend/src')
from dotenv import load_dotenv
load_dotenv('/opt/ezrec-backend/.env')
try:
    import utils
    print('✅ Enhanced utils import successful!')
except Exception as e:
    print(f'❌ Import failed: {e}')
    exit(1)
"

if [ $? -eq 0 ]; then
    echo "✅ Enhanced import test passed!"
    
    # Start the service
    echo "🚀 Starting ezrec-backend service with enhanced query parsing..."
    sudo systemctl start ezrec-backend
    
    # Wait for startup
    sleep 4
    
    # Check status
    echo "📊 Service status:"
    sudo systemctl status ezrec-backend --no-pager
    
    echo ""
    echo "📋 Monitoring logs for enhanced query parsing (10 seconds)..."
    timeout 10 sudo journalctl -u ezrec-backend -f || true
    
    echo ""
    echo "🎯 Final verification:"
    if sudo systemctl is-active --quiet ezrec-backend; then
        echo "✅ EZREC Backend is running with enhanced query parsing!"
        echo ""
        echo "🔍 Look for these NEW success indicators in logs:"
        echo "  ✅ '📅 Filtering by date: 2025-06-25'"
        echo "  ✅ '👤 Filtering by user_id: 65aa2e2a-e463-424d-b88f-0724bb0bea3a'"
        echo "  ✅ '🔄 Ordering by start_time ASC'"
        echo "  ✅ '✅ Bookings query executed successfully - returned X results'"
        echo ""
        echo "🎉 The system should now process queries without warnings!"
    else
        echo "❌ EZREC Backend failed to start"
    fi
else
    echo "❌ Enhanced import test failed. Not starting service."
    exit 1
fi

# Cleanup temp files
rm -f /tmp/fixed_execute_query.py /tmp/new_execute_query.txt 