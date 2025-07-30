# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
Real-time Trading Analytics Automation System that triggers automatically upon trade completion. The system provides comprehensive real-time reporting on trading performance using 8 analytics categories through direct Freqtrade database integration.

## Architecture & Dependencies

### Core Components
- **Database**: SQLite MCP Server (`sqlite-trading-test`) → `~/db_dev/trading_test.db`
- **Data Source**: Direct Freqtrade ORM integration via `freqtrade.persistence.Trade`
- **Main Script**: `trading_analytics_automation.py` - the primary automation engine
- **Logging**: `trading_analytics.log` with both file and console output
- **Scheduling**: Uses Python `schedule` library for automated execution

### Database Schema
The system uses 8 analytics tables:
- `performance_rankings`: Entity performance rankings (pairs, strategies, etc.)
- `risk_metrics`: Risk assessment and stop-loss effectiveness
- `strategy_performance`: Strategy-specific performance metrics
- `timing_analysis`: Time-based trading pattern analysis
- `pair_analytics`: Currency pair performance analysis
- `stop_loss_analytics`: Stop-loss trigger analysis
- `duration_patterns`: Trade duration optimization patterns
- `bot_health_metrics`: System health monitoring
- `analysis_snapshots`: Automation execution tracking

## Development Environment Setup

### Required Dependencies
```bash
pip install freqtrade schedule sqlite3
```

### Database Connection Test
```bash
sqlite3 ~/db_dev/trading_test.db ".tables"
```

### Freqtrade Integration
The system uses direct Freqtrade ORM integration rather than API calls:
```python
from freqtrade.persistence import Trade
all_trades = Trade.get_trades_proxy(pair=None)
```

## Key Configuration

### Database Path
- Analytics DB: `trading_analytics.db` (configurable in constructor)
- MCP Server access: `~/db_dev/trading_test.db` via `sqlite-trading-test`

### Automation Settings
- Check interval: Every 5 minutes via `schedule.every(5).minutes.do()`
- Health check interval: Every hour via `schedule.every().hour.do()`
- Loop check: Every 30 seconds for scheduled jobs
- Health status thresholds:
  - HEALTHY: Win rate ≥70% AND avg profit ≥0.5%
  - WARNING: Win rate ≥50% AND avg profit ≥0%
  - CRITICAL: Below warning thresholds

## Core System Architecture

### Main Class: `TradingAnalyticsAutomator`
- **Initialization**: Takes `analytics_db_path` parameter (default: `trading_analytics.db`)
- **State Tracking**: Maintains `last_processed_trade_id` to avoid reprocessing
- **Scheduling**: Uses Python `schedule` library for automated execution

### Key Methods
- `check_for_new_trades()`: Queries Freqtrade ORM for new completed trades
- `process_new_trades()`: Updates all 8 analytics categories for new trades
- `update_*_analytics()`: Individual methods for each analytics category
- `run_scheduled_analysis()`: Main execution cycle
- `start_automation()`: Continuous automation loop

## Common Development Tasks

### Run Single Analysis Cycle
```bash
python3 trading_analytics_automation.py
# Runs initial analysis then starts continuous automation
```

### Run in Development Mode
```python
# For testing individual components
automator = TradingAnalyticsAutomator('test_analytics.db')
automator.run_scheduled_analysis()  # Single run
```

### Production Deployment
```bash
# Using screen session
screen -S trading_analytics -d -m python3 trading_analytics_automation.py

# Or using nohup
nohup python3 trading_analytics_automation.py > automation.log 2>&1 &
```

### Monitor Logs
```bash
tail -f trading_analytics.log
```

## Integration Points

### MCP Server Connection
- Server: `sqlite-trading-test`
- Database: SQLite at `~/db_dev/trading_test.db`
- Historical trades already migrated

### Freqtrade Integration
- Uses direct ORM integration via `freqtrade.persistence.Trade`
- No API calls required - direct database access
- Filters for completed trades: `not t.is_open`

## Analytics Categories Implementation

### 1. Performance Rankings (`update_performance_rankings`)
- Groups by trading pair
- Calculates profit ratios, win rates, trade counts
- Updates `performance_rankings` table with current metrics

### 2. Risk Metrics (`update_risk_metrics`)
- Tracks stop-loss trigger rates and effectiveness
- Calculates overall risk profile metrics
- Identifies maximum loss scenarios

### 3. Strategy Performance (`update_strategy_performance`)
- Compares different trading strategies
- Tracks win rates and profitability by strategy
- Updates `strategy_performance` table

### 4. Timing Analysis (`update_timing_analysis`)
- Analyzes performance by hour of day
- Groups trades by time patterns
- Identifies optimal trading windows

### 5. Pair Analytics (`update_pair_analytics`)
- Individual currency pair performance
- Duration analysis per pair
- Volatility scoring

### 6. Stop Loss Analytics (`update_stop_loss_analytics`)
- Stop-loss effectiveness by pair
- Average loss when stop-loss triggers
- Stop-loss rate calculations

### 7. Duration Patterns (`update_duration_patterns`)
- Categorizes trades: scalp (≤60min), short_term (≤480min), day_trade (≤1440min), swing_trade (>1440min)
- Performance analysis by duration category
- Optimal exit timing identification

### 8. Bot Health Metrics (`update_bot_health_metrics`)
- Overall system health assessment
- Health status classification (HEALTHY/WARNING/CRITICAL)
- Tracks total trades, win rates, profit metrics

## Monitoring & Logging

### Log Configuration
- File: `trading_analytics.log`
- Console: Real-time output during execution
- Format: `%(asctime)s - %(levelname)s - %(message)s`
- Handlers: Both FileHandler and StreamHandler

### Key Log Messages
- New trade detection: "Found X new completed trades"
- Processing completion: "Successfully processed X trades"
- Individual analytics updates: "Updated [category] analytics"
- Errors: Detailed error messages with exception handling

### Health Status Monitoring
Automatic health status determination:
- **HEALTHY**: Win rate ≥70% AND avg profit ≥0.5%
- **WARNING**: Win rate ≥50% AND avg profit ≥0%
- **CRITICAL**: Below warning thresholds
- Stored in `bot_health_metrics` table with timestamps