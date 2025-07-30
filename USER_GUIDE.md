# User Guide: Real-time Trading Analytics Automation System

## Table of Contents
1. [What This System Does](#what-this-system-does)
2. [Before You Start](#before-you-start)
3. [Step-by-Step Setup](#step-by-step-setup)
4. [Using the System](#using-the-system)
5. [Understanding Your Analytics](#understanding-your-analytics)
6. [Common Tasks](#common-tasks)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Usage](#advanced-usage)

---

## What This System Does

This automation system watches your trading bot's database and automatically calculates comprehensive analytics every time trades complete. Instead of manually running reports, you get real-time insights into:

- **Which trading pairs perform best**
- **How effective your strategies are**
- **When you should trade for maximum profit**
- **Whether your stop-losses are working**
- **If your bot is healthy or needs attention**

The system runs continuously in the background, updating 8 different analytics categories automatically.

---

## Before You Start

### What You Need
- A computer running Linux or macOS
- Python 3.8 or newer
- Your trading bot's SQLite database (usually at `~/db_dev/trading_test.db`)
- At least a few completed trades in your database

### Check Your Database
First, make sure your trading database exists and has trades:

```bash
# Check if database exists
ls -la ~/db_dev/trading_test.db

# Count your completed trades
sqlite3 ~/db_dev/trading_test.db "SELECT COUNT(*) FROM trades WHERE is_open = 0"
```

If you see a number greater than 0, you're ready to proceed!

---

## Step-by-Step Setup

### Step 1: Download the System
```bash
# Clone from GitHub
git clone https://github.com/myownipgit/Real-time-Trading-Analytics-Automation.git
cd Real-time-Trading-Analytics-Automation
```

### Step 2: Set Up Python Environment
```bash
# Create a virtual environment
python3 -m venv venv_analytics

# Activate it
source venv_analytics/bin/activate

# Install required packages
pip install -r requirements.txt
```

### Step 3: Test the Connection
```bash
# Test if the system can access your database
python3 -c "
from trading_analytics_automation_final import TradingAnalyticsAutomator
automator = TradingAnalyticsAutomator()
print('✅ Database connection successful!')
"
```

### Step 4: Run Initial Analysis
```bash
# Process all your existing trades
python3 -c "
from trading_analytics_automation_final import TradingAnalyticsAutomator
automator = TradingAnalyticsAutomator()
automator.run_scheduled_analysis()
print('✅ Initial analysis complete!')
"
```

### Step 5: Start Production Mode
```bash
# Make scripts executable
chmod +x *.sh

# Start the automation system
./start_production.sh
```

---

## Using the System

### Basic Commands

#### Start the System
```bash
./start_production.sh
```
This starts the automation system in the background. It will continuously monitor for new trades.

#### Check System Status
```bash
./check_status.sh
```
Shows you:
- Is the system running?
- How much CPU/memory is it using?
- Recent log activity
- Database connection status
- Recent analytics updates

#### Stop the System
```bash
./stop_production.sh
```
Safely stops the automation system.

#### View Live Logs
```bash
tail -f trading_analytics.log
```
Watch what the system is doing in real-time.

### System Behavior

**When You Start It:**
- The system processes all your existing completed trades
- It creates analytics for 8 different categories
- It starts monitoring for new trades every 5 minutes

**When New Trades Complete:**
- The system detects new completed trades automatically
- It updates all analytics within minutes
- It logs what it processed

**Continuous Operation:**
- Checks for new trades every 5 minutes
- Runs full health checks every hour
- Only processes when there's actually new data

---

## Understanding Your Analytics

The system creates 8 different types of analytics. Here's what each one tells you:

### 1. Performance Rankings (`performance_rankings` table)
**What it shows:** Which trading pairs make you the most money

**Key insights:**
- Which pairs have the highest win rates
- Which pairs generate the most profit
- How much volume you're trading per pair

**Example query:**
```sql
SELECT entity_name, profit_pct, win_rate, trade_count 
FROM performance_rankings 
ORDER BY profit_pct DESC LIMIT 10;
```

### 2. Risk Metrics (`risk_metrics` table)
**What it shows:** How well your risk management is working

**Key insights:**
- How often your stop-losses trigger
- Whether stop-losses are saving you money
- Your maximum drawdown

### 3. Strategy Performance (`strategy_performance` table)
**What it shows:** Which strategies work best

**Key insights:**
- Win rate by strategy
- Profit factor (how much you make vs lose)
- Which strategies are most consistent

**Example query:**
```sql
SELECT strategy_name, win_rate, avg_profit_pct, total_trades 
FROM strategy_performance 
ORDER BY avg_profit_pct DESC;
```

### 4. Timing Analysis (`timing_analysis` table)
**What it shows:** When you should trade for best results

**Key insights:**
- Best hours of the day to trade
- Weekend vs weekday performance
- Optimal trade duration

### 5. Pair Analytics (`pair_analytics` table)
**What it shows:** Detailed stats for each currency pair

**Key insights:**
- Individual pair performance
- Volatility by pair
- Average trade duration per pair

### 6. Stop Loss Analytics (`stop_loss_analytics` table)
**What it shows:** How effective your stop-losses are

**Key insights:**
- Stop-loss trigger rates by pair
- Whether your stop-loss levels are optimal
- Average losses when stop-losses trigger

### 7. Duration Patterns (`duration_patterns` table)
**What it shows:** How trade duration affects profitability

**Categories:**
- **Scalp**: ≤60 minutes
- **Short-term**: ≤480 minutes (8 hours)
- **Day trade**: ≤1440 minutes (24 hours)
- **Swing trade**: >1440 minutes

### 8. Bot Health Metrics (`bot_health_metrics` table)
**What it shows:** Overall system health

**Health Status:**
- **HEALTHY**: Win rate ≥70% AND average profit ≥0.5%
- **WARNING**: Win rate ≥50% AND average profit ≥0%
- **CRITICAL**: Below warning thresholds

---

## Common Tasks

### Check Your Top Performing Pairs
```bash
sqlite3 ~/db_dev/trading_test.db "
SELECT entity_name as pair, 
       ROUND(profit_pct, 2) as avg_profit_pct,
       ROUND(win_rate * 100, 1) as win_rate_pct,
       trade_count
FROM performance_rankings 
ORDER BY profit_pct DESC 
LIMIT 10"
```

### See Your Strategy Performance
```bash
sqlite3 ~/db_dev/trading_test.db "
SELECT strategy_name,
       ROUND(win_rate * 100, 1) as win_rate_pct,
       ROUND(avg_profit_pct, 2) as avg_profit,
       total_trades
FROM strategy_performance 
ORDER BY avg_profit_pct DESC"
```

### Check Your Bot's Health
```bash
sqlite3 ~/db_dev/trading_test.db "
SELECT metric_name,
       ROUND(metric_value, 2) as value,
       metric_unit,
       health_status
FROM bot_health_metrics
ORDER BY metric_name"
```

### Find Your Best Trading Hours
```bash
sqlite3 ~/db_dev/trading_test.db "
SELECT best_performance_hour as best_hour,
       worst_performance_hour as worst_hour,
       ROUND(weekend_performance_pct, 2) as weekend_profit,
       ROUND(weekday_performance_pct, 2) as weekday_profit
FROM timing_analysis"
```

---

## Troubleshooting

### Problem: System Won't Start

**Error:** `ModuleNotFoundError: No module named 'schedule'`
```bash
# Solution: Activate virtual environment and install packages
source venv_analytics/bin/activate
pip install -r requirements.txt
```

**Error:** `Database not found`
```bash
# Solution: Check your database path
ls -la ~/db_dev/trading_test.db

# If it's somewhere else, edit the script:
# In trading_analytics_automation_final.py, line 28, change the path
```

### Problem: No New Trades Being Processed

**Check these things:**
1. **Are trades actually completing?**
   ```bash
   sqlite3 ~/db_dev/trading_test.db "SELECT COUNT(*) FROM trades WHERE is_open = 0"
   ```

2. **Is the system running?**
   ```bash
   ./check_status.sh
   ```

3. **Check the logs for errors:**
   ```bash
   tail -20 trading_analytics.log
   ```

### Problem: System Using Too Much CPU/Memory

**Check resource usage:**
```bash
./check_status.sh
```

**If CPU is high:**
- This is normal during initial processing of many trades
- Should reduce to <5% CPU after initial analysis

**If memory is high:**
- Restart the system: `./stop_production.sh && ./start_production.sh`

### Problem: Analytics Look Wrong

**Check data integrity:**
```bash
# Verify your trades table has the required columns
sqlite3 ~/db_dev/trading_test.db ".schema trades"

# Check for NULL values that might affect calculations
sqlite3 ~/db_dev/trading_test.db "
SELECT COUNT(*) as total_trades,
       COUNT(profit_pct) as trades_with_profit,
       COUNT(trade_duration) as trades_with_duration
FROM trades WHERE is_open = 0"
```

**Force recalculation:**
```bash
# Stop system
./stop_production.sh

# Clear analytics and recalculate
sqlite3 ~/db_dev/trading_test.db "
DELETE FROM performance_rankings;
DELETE FROM strategy_performance;
DELETE FROM bot_health_metrics;
DELETE FROM analysis_snapshots;
"

# Restart system (will recalculate everything)
./start_production.sh
```

---

## Advanced Usage

### Custom Database Location

If your database is not at `~/db_dev/trading_test.db`, edit line 28 in `trading_analytics_automation_final.py`:

```python
# Change this line:
analytics_db_path = os.path.expanduser('~/db_dev/trading_test.db')

# To your path:
analytics_db_path = '/path/to/your/database.db'
```

### Running on Different Schedule

To change the monitoring frequency, edit lines 470-473 in `trading_analytics_automation_final.py`:

```python
# Current: check every 5 minutes
schedule.every(5).minutes.do(self.run_scheduled_analysis)

# Change to every 1 minute:
schedule.every(1).minutes.do(self.run_scheduled_analysis)

# Change to every 15 minutes:
schedule.every(15).minutes.do(self.run_scheduled_analysis)
```

### Integration with External Tools

**Access via MCP Server:**
The database can be accessed through the `sqlite-trading-test` MCP server for external integrations.

**Direct Database Queries:**
All analytics are stored in standard SQLite tables that can be queried by any tool that supports SQLite.

**API Integration:**
You can import the automator class in your own Python scripts:

```python
from trading_analytics_automation_final import TradingAnalyticsAutomator

# Initialize
automator = TradingAnalyticsAutomator()

# Run analysis manually
automator.run_scheduled_analysis()

# Access database directly
import sqlite3
conn = sqlite3.connect(automator.analytics_db)
# ... your queries here
```

### Monitoring Multiple Databases

To monitor multiple trading databases, create separate instances:

```python
# monitor_multiple.py
from trading_analytics_automation_final import TradingAnalyticsAutomator

# Create separate automators for different databases
bot1 = TradingAnalyticsAutomator('/path/to/bot1.db')
bot2 = TradingAnalyticsAutomator('/path/to/bot2.db')

# Run analysis on both
bot1.run_scheduled_analysis()
bot2.run_scheduled_analysis()
```

---

## Getting Help

If you run into issues:

1. **Check the logs first:**
   ```bash
   tail -50 trading_analytics.log
   ```

2. **Verify system status:**
   ```bash
   ./check_status.sh
   ```

3. **Test database connectivity:**
   ```bash
   sqlite3 ~/db_dev/trading_test.db "SELECT COUNT(*) FROM trades"
   ```

4. **Restart the system:**
   ```bash
   ./stop_production.sh
   ./start_production.sh
   ```

5. **Check GitHub issues:**
   Visit the repository for known issues and solutions.

---

**System Version**: v1.0  
**Last Updated**: 2025-07-30  
**Compatibility**: Linux, macOS, Python 3.8+