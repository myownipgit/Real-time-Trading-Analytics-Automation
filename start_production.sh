#!/bin/bash

# Real-time Trading Analytics Automation - Production Starter
# This script starts the automation system in the background for continuous operation

echo "Starting Real-time Trading Analytics Automation System..."

# Navigate to project directory
cd "$(dirname "$0")"

# Activate virtual environment
source venv_analytics/bin/activate

# Check if the automation is already running
if pgrep -f "trading_analytics_automation_final.py" > /dev/null; then
    echo "Trading Analytics Automation is already running!"
    echo "PID: $(pgrep -f trading_analytics_automation_final.py)"
    exit 1
fi

# Start the automation system using screen
screen -S trading_analytics -d -m python3 trading_analytics_automation_final.py

# Wait a moment for startup
sleep 2

# Check if it started successfully
if pgrep -f "trading_analytics_automation_final.py" > /dev/null; then
    PID=$(pgrep -f "trading_analytics_automation_final.py")
    echo "✅ Trading Analytics Automation System started successfully!"
    echo "   PID: $PID"
    echo "   Screen session: trading_analytics"
    echo ""
    echo "Useful commands:"
    echo "   View logs: tail -f trading_analytics.log"
    echo "   Attach to session: screen -r trading_analytics"
    echo "   Stop system: kill $PID"
    echo "   Check status: ./check_status.sh"
else
    echo "❌ Failed to start Trading Analytics Automation System"
    echo "Check the logs for errors: cat trading_analytics.log"
    exit 1
fi