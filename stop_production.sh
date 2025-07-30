#!/bin/bash

# Real-time Trading Analytics Automation - Production Stopper
# This script safely stops the automation system

echo "Stopping Real-time Trading Analytics Automation System..."

# Check if the process is running
if pgrep -f "trading_analytics_automation_final.py" > /dev/null; then
    PID=$(pgrep -f "trading_analytics_automation_final.py")
    echo "Found running process with PID: $PID"
    
    # Gracefully stop the process
    echo "Sending SIGTERM signal..."
    kill $PID
    
    # Wait for graceful shutdown
    sleep 3
    
    # Check if it's still running
    if pgrep -f "trading_analytics_automation_final.py" > /dev/null; then
        echo "Process still running, forcing shutdown..."
        kill -9 $PID
        sleep 1
    fi
    
    # Verify it's stopped
    if pgrep -f "trading_analytics_automation_final.py" > /dev/null; then
        echo "❌ Failed to stop the process"
        exit 1
    else
        echo "✅ Trading Analytics Automation System stopped successfully"
    fi
    
    # Kill the screen session if it exists
    if screen -list | grep -q "trading_analytics"; then
        screen -S trading_analytics -X quit
        echo "✅ Screen session terminated"
    fi
    
else
    echo "Trading Analytics Automation System is not running"
fi

echo "Final status check..."
./check_status.sh