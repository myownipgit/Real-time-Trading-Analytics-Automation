# Installation Guide

## Prerequisites

- Python 3.8 or higher
- SQLite3
- **Freqtrade trading bot** with completed trades
- Access to your Freqtrade database (`~/workspace/freqtrade_bot/user_data/tradesv3.sqlite`)
- Unix-like operating system (Linux/macOS)

> **Note**: This system is designed specifically for [Freqtrade](https://github.com/freqtrade/freqtrade) cryptocurrency trading bots. See [FREQTRADE_INTEGRATION.md](FREQTRADE_INTEGRATION.md) for detailed integration information.

## Quick Installation

### 1. Clone the Repository

```bash
git clone https://github.com/myownipgit/Real-time-Trading-Analytics-Automation.git
cd Real-time-Trading-Analytics-Automation
```

### 2. Create Virtual Environment

```bash
python3 -m venv venv_analytics
source venv_analytics/bin/activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure Database Path

The system expects your Freqtrade database at `~/workspace/freqtrade_bot/user_data/tradesv3.sqlite`. If your Freqtrade database is located elsewhere, update the path in `trading_analytics_automation_final.py`:

```python
# Find your Freqtrade database first
find ~ -name "tradesv3.sqlite" 2>/dev/null

# Update line 28 in trading_analytics_automation_final.py:
analytics_db_path = os.path.expanduser('~/workspace/freqtrade_bot/user_data/tradesv3.sqlite')
```

### 5. Verify Freqtrade Database Schema

Ensure your Freqtrade database has the required tables and trades:

```bash
# Check database exists
ls -la ~/workspace/freqtrade_bot/user_data/tradesv3.sqlite

# Check tables exist
sqlite3 ~/workspace/freqtrade_bot/user_data/tradesv3.sqlite ".tables"

# Count completed trades (should be > 0)
sqlite3 ~/workspace/freqtrade_bot/user_data/tradesv3.sqlite \
  "SELECT COUNT(*) FROM trades WHERE is_open = 0"
```

Required tables:
- trades
- performance_rankings
- risk_metrics
- strategy_performance
- timing_analysis
- pair_analytics
- stop_loss_analytics
- duration_patterns
- bot_health_metrics
- analysis_snapshots

### 6. Test the Installation

Run a single analysis cycle to verify everything works:

```bash
python3 -c "
from trading_analytics_automation_final import TradingAnalyticsAutomator
automator = TradingAnalyticsAutomator()
automator.run_scheduled_analysis()
"
```

### 7. Start Production System

```bash
./start_production.sh
```

## Database Schema Requirements

Your `trades` table must include these columns:
- trade_id (INTEGER PRIMARY KEY)
- pair (TEXT)
- base_currency (TEXT)
- quote_currency (TEXT)
- is_open (BOOLEAN)
- strategy (TEXT)
- profit_pct (REAL)
- profit_abs (REAL)
- profit_ratio (REAL)
- trade_duration (INTEGER) - in minutes
- exit_reason (TEXT)
- stop_loss_pct (REAL)
- stake_amount (REAL)
- open_date (TEXT/DATETIME)
- close_date (TEXT/DATETIME)

## Troubleshooting

### ModuleNotFoundError: No module named 'schedule'

```bash
source venv_analytics/bin/activate
pip install schedule
```

### Database Access Error

1. Check database exists:
```bash
ls -la ~/db_dev/trading_test.db
```

2. Verify permissions:
```bash
chmod 644 ~/db_dev/trading_test.db
```

### Process Already Running

```bash
./stop_production.sh
./start_production.sh
```

## Next Steps

1. Monitor the system: `./check_status.sh`
2. View logs: `tail -f trading_analytics.log`
3. Query analytics: See README.md for example queries