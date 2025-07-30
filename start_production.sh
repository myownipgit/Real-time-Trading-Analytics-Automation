#!/bin/bash

# Real-time Trading Analytics Automation - Production Starter
# This script safely starts the automation system in production mode

echo "=== Starting Real-time Trading Analytics Automation ==="

# Check if virtual environment exists
if [ ! -d "venv_analytics" ]; then
    echo "❌ Virtual environment not found!"
    echo "   Please run: python3 -m venv venv_analytics"
    echo "   Then: source venv_analytics/bin/activate && pip install -r requirements.txt"
    exit 1
fi

# Check if already running
if pgrep -f "trading_analytics_automation_final.py" > /dev/null; then
    echo "❌ Process already running!"
    echo "   Use ./check_status.sh to see current status"
    echo "   Use ./stop_production.sh to stop it first"
    exit 1
fi

# Check if screen is installed
if ! command -v screen &> /dev/null; then
    echo "❌ screen command not found!"
    echo "   Please install: sudo apt-get install screen (Ubuntu/Debian)"
    echo "                  brew install screen (macOS)"
    exit 1
fi

# Check database exists
DB_PATH="$HOME/db_dev/trading_test.db"
if [ ! -f "$DB_PATH" ]; then
    echo "❌ Database not found at: $DB_PATH"
    echo "   Please ensure your trading database exists"
    exit 1
fi

# Start the process in a screen session
echo "Starting automation in screen session..."
screen -S trading_analytics -d -m bash -c "source venv_analytics/bin/activate && python3 trading_analytics_automation_final.py"

# Wait a moment for process to start
sleep 2

# Check if started successfully
if pgrep -f "trading_analytics_automation_final.py" > /dev/null; then
    PID=$(pgrep -f "trading_analytics_automation_final.py")
    echo "✅ Automation started successfully!"
    echo "   PID: $PID"
    echo "   Screen session: trading_analytics"
    echo ""
    echo "Useful commands:"
    echo "  View logs:        screen -r trading_analytics"
    echo "  Detach from logs: Ctrl+A, then D"
    echo "  Check status:     ./check_status.sh"
    echo "  Stop system:      ./stop_production.sh"
    echo ""
    echo "Monitoring logs in real-time:"
    tail -f trading_analytics.log
else
    echo "❌ Failed to start automation"
    echo "   Check logs for errors"
    exit 1
fi