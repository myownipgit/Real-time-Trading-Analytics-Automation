#!/bin/bash

# Real-time Trading Analytics Automation - Production Stopper
# This script safely stops the automation system

echo "=== Stopping Real-time Trading Analytics Automation ==="

# Check if running
if pgrep -f "trading_analytics_automation_final.py" > /dev/null; then
    PID=$(pgrep -f "trading_analytics_automation_final.py")
    echo "Found running process with PID: $PID"
    
    # Kill the process
    echo "Sending termination signal..."
    kill $PID
    
    # Wait for graceful shutdown
    sleep 2
    
    # Check if still running
    if pgrep -f "trading_analytics_automation_final.py" > /dev/null; then
        echo "Process still running, forcing termination..."
        kill -9 $PID
        sleep 1
    fi
    
    # Clean up screen session if exists
    if screen -list | grep -q "trading_analytics"; then
        echo "Cleaning up screen session..."
        screen -S trading_analytics -X quit
    fi
    
    echo "✅ Automation stopped successfully"
    
    # Show last few log entries
    echo ""
    echo "Last log entries:"
    if [ -f "trading_analytics.log" ]; then
        tail -5 trading_analytics.log
    fi
    
else
    echo "❌ No running process found"
fi