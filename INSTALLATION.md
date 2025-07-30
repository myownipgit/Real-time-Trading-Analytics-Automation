# Installation Guide

## Prerequisites

- Python 3.8 or higher
- SQLite3
- Access to your trading bot's database (`~/db_dev/trading_test.db`)
- Unix-like operating system (Linux/macOS)

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

The system expects your trading database at `~/db_dev/trading_test.db`. If your database is located elsewhere, update the path in `trading_analytics_automation_final.py`:

```python
analytics_db_path = os.path.expanduser('~/db_dev/trading_test.db')
```

### 5. Verify Database Schema

Ensure your database has the required tables:

```bash
sqlite3 ~/db_dev/trading_test.db ".tables"
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