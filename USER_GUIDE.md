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

The system creates 8 different types of analytics, each with dedicated SQL files for advanced analysis. Here's what each one tells you:

### 1. Performance Rankings (`performance_rankings` table)
**SQL File:** `sql/performance_rankings.sql`  
**What it shows:** Which trading pairs make you the most money

**Key insights:**
- Which pairs have the highest win rates
- Which pairs generate the most profit
- How much volume you're trading per pair

**Business Impact:** Use this to allocate more capital to your best-performing pairs

**Example queries:**
```sql
-- Top 10 performing pairs
SELECT entity_name, profit_pct, win_rate, trade_count 
FROM performance_rankings 
WHERE ranking_type = 'by_pair'
ORDER BY profit_pct DESC LIMIT 10;

-- Performance distribution analysis
SELECT 
    CASE 
        WHEN profit_pct >= 2.0 THEN 'Excellent (≥2%)'
        WHEN profit_pct >= 1.0 THEN 'Good (1-2%)'
        WHEN profit_pct >= 0.0 THEN 'Break-even (0-1%)'
        ELSE 'Losing (<0%)'
    END as performance_category,
    COUNT(*) as pair_count
FROM performance_rankings 
WHERE ranking_type = 'by_pair'
GROUP BY performance_category;
```

### 2. Risk Metrics (`risk_metrics` table)
**SQL File:** `sql/risk_metrics.sql`  
**What it shows:** How well your risk management is working

**Key insights:**
- How often your stop-losses trigger
- Whether stop-losses are saving you money
- Your maximum drawdown and Value at Risk (VaR)

**Business Impact:** Prevents catastrophic losses by monitoring risk levels

**Example queries:**
```sql
-- Overall portfolio risk summary
SELECT 
    stop_loss_triggered_count,
    stop_loss_effectiveness_pct,
    max_drawdown_pct,
    sharpe_ratio
FROM risk_metrics 
WHERE metric_type = 'overall';

-- High-risk pairs needing attention
SELECT 
    entity_name as trading_pair,
    max_drawdown_pct as worst_loss,
    volatility_pct,
    stop_loss_effectiveness_pct
FROM risk_metrics 
WHERE metric_type = 'by_pair'
  AND (max_drawdown_pct < -10 OR volatility_pct > 5)
ORDER BY max_drawdown_pct ASC;
```

### 3. Strategy Performance (`strategy_performance` table)
**SQL File:** `sql/strategy_performance.sql`  
**What it shows:** Which strategies work best

**Key insights:**
- Win rate by strategy
- Profit factor (how much you make vs lose)
- Sharpe ratios and risk-adjusted returns
- Consecutive win/loss streaks

**Business Impact:** Optimize your bot by prioritizing winning strategies

**Example queries:**
```sql
-- Risk-adjusted strategy ranking
SELECT 
    strategy_name,
    avg_profit_pct,
    sharpe_ratio,
    sortino_ratio,
    calmar_ratio,
    max_consecutive_losses
FROM strategy_performance 
WHERE total_trades >= 10
ORDER BY sharpe_ratio DESC;

-- Strategy efficiency analysis
SELECT 
    strategy_name,
    avg_profit_pct,
    avg_trade_duration_minutes / 60.0 as avg_hours,
    (avg_profit_pct / (avg_trade_duration_minutes / 60.0)) as profit_per_hour
FROM strategy_performance 
WHERE avg_trade_duration_minutes > 0
ORDER BY profit_per_hour DESC;
```

### 4. Timing Analysis (`timing_analysis` table)
**SQL File:** `sql/timing_analysis.sql`  
**What it shows:** When you should trade for best results

**Key insights:**
- Best hours of the day to trade
- Weekend vs weekday performance
- Market session analysis (US, EU, Asia)
- Optimal trade duration

**Business Impact:** Trade during profitable hours, avoid poor time periods

**Example queries:**
```sql
-- Best trading hours
SELECT 
    hour_of_day,
    time_period_name,
    trade_count,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(avg_profit_pct, 2) as avg_profit_pct
FROM timing_analysis 
WHERE time_category = 'hourly'
ORDER BY avg_profit_pct DESC;

-- Market session analysis
SELECT 
    CASE 
        WHEN hour_of_day IN (13,14,15,16,17,18,19,20) THEN 'US Market Hours'
        WHEN hour_of_day IN (8,9,10,11,12,13,14,15) THEN 'EU Market Hours'
        WHEN hour_of_day IN (0,1,2,3,4,5,6,7) THEN 'Asia Market Hours'
        ELSE 'Off Market Hours'
    END as market_session,
    ROUND(AVG(avg_profit_pct), 2) as session_avg_profit
FROM timing_analysis 
WHERE time_category = 'hourly'
GROUP BY market_session
ORDER BY session_avg_profit DESC;
```

### 5. Pair Analytics (`pair_analytics` table)
**SQL File:** `sql/pair_analytics.sql`  
**What it shows:** Detailed analysis of individual currency pairs

**Key insights:**
- Individual pair performance and characteristics
- Volatility patterns per pair
- Base/quote currency analysis
- Efficiency ratios and optimal duration per pair

**Business Impact:** Tailor your trading approach to each pair's unique behavior

**Example queries:**
```sql
-- Most consistent pairs (low volatility, good performance)
SELECT 
    pair,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(price_volatility_pct, 2) as price_volatility_pct,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(sharpe_ratio, 3) as sharpe_ratio
FROM pair_analytics 
WHERE total_trades >= 5 AND avg_profit_pct > 0
ORDER BY sharpe_ratio DESC, price_volatility_pct ASC;

-- Base currency performance analysis
SELECT 
    base_currency,
    COUNT(*) as pair_count,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit,
    ROUND(AVG(win_rate * 100), 1) as avg_win_rate,
    ROUND(SUM(total_profit_abs), 2) as total_profit
FROM pair_analytics 
GROUP BY base_currency
HAVING pair_count >= 2
ORDER BY avg_profit DESC;
```

### 6. Stop Loss Analytics (`stop_loss_analytics` table)
**SQL File:** `sql/stop_loss_analytics.sql`  
**What it shows:** How effective your stop-losses are

**Key insights:**
- Stop-loss trigger rates by pair and strategy
- Effectiveness percentages
- Optimal stop-loss levels
- Loss prevention analysis

**Business Impact:** Fine-tune risk management by optimizing stop-loss levels

**Example queries:**
```sql
-- Stop-loss effectiveness by pair
SELECT 
    pair,
    ROUND(sl_trigger_rate_pct, 1) as sl_trigger_rate_pct,
    ROUND(sl_effectiveness_pct, 1) as sl_effectiveness_pct,
    ROUND(avg_sl_level_pct, 1) as avg_sl_level_pct,
    ROUND(optimal_sl_level_pct, 1) as optimal_sl_level_pct,
    CASE 
        WHEN sl_effectiveness_pct < 50 THEN 'Needs Improvement'
        WHEN sl_trigger_rate_pct > 30 THEN 'Too Aggressive'
        WHEN sl_trigger_rate_pct < 5 THEN 'Too Loose'
        ELSE 'Acceptable'
    END as assessment
FROM stop_loss_analytics 
WHERE analysis_type = 'by_pair'
ORDER BY sl_effectiveness_pct ASC;

-- Stop-loss level optimization
SELECT 
    CASE 
        WHEN stop_loss_level_pct <= -10 THEN 'Very Tight (≤-10%)'
        WHEN stop_loss_level_pct <= -5 THEN 'Tight (-5% to -10%)'
        WHEN stop_loss_level_pct <= -2 THEN 'Moderate (-2% to -5%)'
        ELSE 'Loose (>-2%)'
    END as sl_level_category,
    ROUND(AVG(sl_effectiveness_pct), 1) as avg_effectiveness,
    ROUND(AVG(sl_trigger_rate_pct), 1) as avg_trigger_rate
FROM stop_loss_analytics 
WHERE analysis_type = 'by_pair'
GROUP BY sl_level_category
ORDER BY avg_effectiveness DESC;
```

### 7. Duration Patterns (`duration_patterns` table)
**SQL File:** `sql/duration_patterns.sql`  
**What it shows:** How trade duration affects profitability and efficiency

**Key insights:**
- Profit-per-hour efficiency by duration category
- Optimal exit timing strategies
- Duration preferences by pair and strategy

**Duration Categories:**
- **Scalp**: ≤60 minutes
- **Short-term**: ≤480 minutes (8 hours)
- **Day trade**: ≤1440 minutes (24 hours)
- **Swing trade**: >1440 minutes

**Business Impact:** Maximize profit efficiency by identifying optimal trade duration ranges

**Example queries:**
```sql
-- Duration category efficiency
SELECT 
    duration_category,
    trade_count,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(profit_per_hour, 4) as profit_per_hour,
    ROUND(optimal_exit_timing_minutes / 60.0, 1) as avg_duration_hours
FROM duration_patterns 
WHERE pattern_type = 'duration_based'
ORDER BY profit_per_hour DESC;

-- Optimal duration by pair
SELECT 
    pair,
    duration_category,
    ROUND(profit_per_hour, 4) as profit_per_hour,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(optimal_exit_timing_minutes / 60.0, 1) as optimal_hours
FROM duration_patterns 
WHERE pattern_type = 'by_pair'
  AND trade_count >= 3
ORDER BY pair, profit_per_hour DESC;
```

### 8. Bot Health Metrics (`bot_health_metrics` table)
**SQL File:** `sql/bot_health_metrics.sql`  
**What it shows:** Comprehensive system health monitoring with automated alerts

**Key insights:**
- Overall performance health scores
- Portfolio diversification metrics
- Trading activity consistency
- Early warning alerts for performance degradation

**Health Status Thresholds:**
- **HEALTHY**: Win rate ≥60% AND average profit ≥0.5%
- **WARNING**: Win rate ≥40% AND average profit ≥0%
- **CRITICAL**: Below warning thresholds

**Business Impact:** Provides early warning system for performance issues

**Example queries:**
```sql
-- Overall health dashboard
SELECT 
    metric_name,
    ROUND(metric_value, 2) as metric_value,
    metric_unit,
    health_status,
    CASE 
        WHEN health_status = 'CRITICAL' THEN 'Immediate Action Required'
        WHEN health_status = 'WARNING' THEN 'Monitoring Recommended'
        ELSE 'No Action Needed'
    END as priority_level
FROM bot_health_metrics 
ORDER BY 
    CASE health_status 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'WARNING' THEN 2 
        WHEN 'HEALTHY' THEN 3 
    END;

-- Health score calculation
SELECT 
    ROUND(COUNT(CASE WHEN health_status = 'HEALTHY' THEN 1 END) * 100.0 / COUNT(*), 1) as health_score_pct,
    COUNT(CASE WHEN health_status = 'CRITICAL' THEN 1 END) as critical_alerts,
    COUNT(CASE WHEN health_status = 'WARNING' THEN 1 END) as warning_alerts
FROM bot_health_metrics;
```

## 🔧 Using SQL Analytics Files

Each analytics category includes comprehensive SQL files with:

### What's in Each SQL File:
- **Table creation** with proper indexing
- **Data population** queries for automation
- **Analysis examples** for manual exploration
- **Query templates** for custom analysis
- **Maintenance scripts** for data quality

### Manual SQL Analysis:
```bash
# Run specific analytics category
sqlite3 ~/db_dev/trading_test.db < sql/performance_rankings.sql

# Execute custom queries from SQL files
sqlite3 ~/db_dev/trading_test.db < sql/timing_analysis.sql

# Run all analytics manually (usually automated)
for sql_file in sql/*.sql; do
    echo "Processing $sql_file..."
    sqlite3 ~/db_dev/trading_test.db < "$sql_file"
done
```

### Advanced Analytics Examples:
```bash
# Find optimal trading hours
sqlite3 ~/db_dev/trading_test.db "
SELECT time_period_name, avg_profit_pct, trade_count
FROM timing_analysis 
WHERE time_category = 'hourly'
ORDER BY avg_profit_pct DESC"

# Analyze stop-loss effectiveness
sqlite3 ~/db_dev/trading_test.db "
SELECT pair, sl_effectiveness_pct, sl_trigger_rate_pct
FROM stop_loss_analytics 
WHERE analysis_type = 'by_pair'
ORDER BY sl_effectiveness_pct DESC"
```

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