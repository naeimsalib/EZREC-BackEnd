#!/bin/bash

echo "🔍 EZREC Deployment Status Check"
echo "================================"

echo "📋 Checking SupabaseManager execute_query method in deployment:"
sudo grep -A 15 "async def execute_query" /opt/ezrec-backend/src/utils.py

echo ""
echo "📋 Checking for warning message patterns:"
sudo grep -n "Only SELECT queries supported" /opt/ezrec-backend/src/utils.py

echo ""
echo "📋 Checking orchestrator.py imports:"
sudo grep -n "from utils import" /opt/ezrec-backend/src/orchestrator.py

echo ""
echo "📋 Checking how orchestrator calls execute_query:"
sudo grep -A 5 -B 5 "execute_query" /opt/ezrec-backend/src/orchestrator.py

echo ""
echo "📋 Recent service logs (last 20 lines):"
sudo journalctl -u ezrec-backend --lines=20 --no-pager

echo ""
echo "📋 Current service status:"
sudo systemctl status ezrec-backend --no-pager 