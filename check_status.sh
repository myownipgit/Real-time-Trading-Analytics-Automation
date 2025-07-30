#!/bin/bash

# Real-time Trading Analytics Automation - Status Checker
# This script checks the status of the automation system

echo "=== Trading Analytics Automation System Status ==="

# Check if the process is running
if pgrep -f "trading_analytics_automation_final.py" > /dev/null; then
    PID=$(pgrep -f "trading_analytics_automation_final.py")
    echo "✅ Status: RUNNING"
    echo "   PID: $PID"
    
    # Get process info
    RUNTIME=$(ps -o etime= -p $PID | tr -d ' ')
    CPU=$(ps -o pcpu= -p $PID | tr -d ' ')
    MEM=$(ps -o pmem= -p $PID | tr -d ' ')
    
    echo "   Runtime: $RUNTIME"
    echo "   CPU Usage: ${CPU}%"
    echo "   Memory Usage: ${MEM}%"
    
    # Check if screen session exists
    if screen -list | grep -q "trading_analytics"; then
        echo "   Screen Session: ✅ Available (trading_analytics)"
    else
        echo "   Screen Session: ❌ Not found"
    fi
    
else
    echo "❌ Status: NOT RUNNING"
fi

echo ""
echo "=== Recent Log Activity ==="
if [ -f "trading_analytics.log" ]; then
    echo "Last 5 log entries:"
    tail -5 trading_analytics.log
    echo ""
    echo "Log file size: $(du -h trading_analytics.log | cut -f1)"
else
    echo "No log file found"
fi

echo ""
echo "=== Database Connection Test ==="
if python3 -c "
import sqlite3
import os
try:
    db_path = os.path.expanduser('~/db_dev/trading_test.db')
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) FROM trades WHERE is_open = 0')
    count = cursor.fetchone()[0]
    print(f'✅ Database accessible: {count} completed trades')
    conn.close()
except Exception as e:
    print(f'❌ Database error: {e}')
" 2>/dev/null; then
    :
else
    echo "❌ Database connection failed"
fi

echo ""
echo "=== Recent Analytics Updates ==="
python3 -c "
import sqlite3
import os
from datetime import datetime, timedelta
try:
    db_path = os.path.expanduser('~/db_dev/trading_test.db')
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check recent analysis snapshots
    cursor.execute('''
        SELECT snapshot_type, status, records_processed, 
               datetime(last_analysis_run) as last_run
        FROM analysis_snapshots 
        ORDER BY last_analysis_run DESC 
        LIMIT 3
    ''')
    
    snapshots = cursor.fetchall()
    if snapshots:
        print('Recent analysis runs:')
        for snap in snapshots:
            print(f'  {snap[0]}: {snap[1]} ({snap[2]} records) at {snap[3]}')
    else:
        print('No recent analysis runs found')
    
    conn.close()
except Exception as e:
    print(f'Error checking analytics: {e}')
" 2>/dev/null