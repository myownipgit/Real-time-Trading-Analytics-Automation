# Freqtrade Integration Guide

## Overview

This Real-time Trading Analytics Automation System is specifically designed to work with [Freqtrade](https://github.com/freqtrade/freqtrade), an open-source cryptocurrency trading bot framework. The system monitors your Freqtrade bot's database and automatically generates comprehensive analytics as trades complete.

## What is Freqtrade?

[Freqtrade](https://www.freqtrade.io/en/stable/) is a Python-based cryptocurrency trading bot that:

- **Supports major exchanges** (Binance, Kraken, Bybit, etc.)
- **Allows custom strategies** written in Python using pandas
- **Provides backtesting and optimization** tools
- **Offers multiple trading modes** (dry-run simulation and live trading)
- **Can be controlled** via Telegram bot or web interface

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│                 │    │                  │    │                     │
│   Freqtrade     │───▶│  tradesv3.sqlite │───▶│  Analytics System   │
│   Trading Bot   │    │   Database       │    │  (This Project)     │
│                 │    │                  │    │                     │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
         │                        │                         │
         │                        │                         │
    ┌────▼────┐              ┌────▼────┐               ┌────▼────┐
    │Exchange │              │ Trade   │               │8 Analytics│
    │ API     │              │Objects  │               │Categories │
    │         │              │         │               │           │
    └─────────┘              └─────────┘               └─────────┘
```

## How It Works

### 1. Freqtrade Operation
- Freqtrade executes trading strategies on cryptocurrency exchanges
- Each trade (buy/sell cycle) is stored as a **Trade Object** in SQLite database
- Trade data includes entry/exit prices, timing, profit/loss, and strategy information

### 2. Database Storage
- **Default Location**: `~/workspace/freqtrade_bot/user_data/tradesv3.sqlite`
- **Database Type**: SQLite (lightweight, file-based)
- **Primary Table**: `trades` (contains all trade records)

### 3. Analytics Processing
- Our system monitors the Freqtrade database for completed trades (`is_open = 0`)
- Automatically processes new trades every 5 minutes
- Generates 8 comprehensive analytics categories
- Updates health metrics and performance rankings

## Freqtrade Trade Object Structure

Freqtrade stores each trade as a [Trade Object](https://www.freqtrade.io/en/stable/trade-object/) with these key fields:

### Core Trade Fields
```python
# Trade identification
trade_id: int           # Unique trade identifier
pair: str              # Trading pair (e.g., "BTC/USDT")
is_open: bool          # True if trade is active, False if completed

# Financial data
stake_amount: float    # Amount invested (in quote currency)
amount: float          # Amount purchased (in base currency)
open_rate: float       # Entry price
close_rate: float      # Exit price (None if still open)

# Timing
open_date_utc: datetime    # When trade was opened
close_date_utc: datetime   # When trade was closed

# Performance
close_profit: float    # Profit ratio (0.05 = 5% profit)
close_profit_abs: float # Absolute profit in stake currency

# Strategy information
strategy: str          # Name of strategy that opened trade
enter_tag: str         # Entry signal tag
exit_reason: str       # Why trade was closed (roi, stop_loss, etc.)

# Risk management
stop_loss: float       # Stop loss price
stop_loss_pct: float   # Stop loss percentage
```

## Database Schema Mapping

### Freqtrade → Analytics System

Our analytics system expects specific column names. Here's how Freqtrade fields map to our system:

| **Freqtrade Field** | **Analytics System Field** | **Description** |
|---------------------|---------------------------|---------------|
| `id` | `trade_id` | Unique trade identifier |
| `pair` | `pair` | Trading pair (BTC/USDT) |
| `is_open` | `is_open` | Trade status (0=closed, 1=open) |
| `strategy` | `strategy` | Strategy name |
| `close_profit` | `profit_ratio` | Profit ratio (decimal) |
| `close_profit * 100` | `profit_pct` | Profit percentage |
| `close_profit_abs` | `profit_abs` | Absolute profit |
| `(close_date - open_date)` | `trade_duration` | Duration in minutes |
| `exit_reason` | `exit_reason` | Why trade closed |
| `stop_loss_pct` | `stop_loss_pct` | Stop loss percentage |
| `stake_amount` | `stake_amount` | Investment amount |
| `open_date_utc` | `open_date` | Trade opening time |
| `close_date_utc` | `close_date` | Trade closing time |

### Currency Pair Parsing
From Freqtrade pairs like "BTC/USDT":
- `base_currency` = "BTC" (what you're buying)
- `quote_currency` = "USDT" (what you're paying with)

## Setup for Freqtrade Integration

### 1. Locate Your Freqtrade Database

Standard Freqtrade database locations:

```bash
# Default location
~/workspace/freqtrade_bot/user_data/tradesv3.sqlite

# Alternative locations
~/.freqtrade/tradesv3.sqlite
~/freqtrade/user_data/tradesv3.sqlite
```

Find your database:
```bash
find ~ -name "tradesv3.sqlite" 2>/dev/null
```

### 2. Configure Analytics System

Update the database path in `trading_analytics_automation_final.py`:

```python
# Line 28 - Update this path to match your Freqtrade database
analytics_db_path = os.path.expanduser('~/workspace/freqtrade_bot/user_data/tradesv3.sqlite')
```

### 3. Verify Freqtrade Schema

Check that your Freqtrade database has the expected structure:

```bash
sqlite3 ~/workspace/freqtrade_bot/user_data/tradesv3.sqlite ".schema trades"
```

Should show a table with fields like `id`, `pair`, `is_open`, `strategy`, etc.

### 4. Test Integration

```bash
# Count completed trades
sqlite3 ~/workspace/freqtrade_bot/user_data/tradesv3.sqlite \
  "SELECT COUNT(*) FROM trades WHERE is_open = 0"

# Test analytics system connection
python3 -c "
from trading_analytics_automation_final import TradingAnalyticsAutomator
automator = TradingAnalyticsAutomator('~/workspace/freqtrade_bot/user_data/tradesv3.sqlite')
print('✅ Connected to Freqtrade database successfully!')
"
```

## Analytics Categories Explained

### 1. Performance Rankings
**Analyzes**: Which trading pairs make you the most profit
**Uses**: `pair`, `profit_pct`, `trade_count`, `stake_amount`
**Shows**: Top/bottom performing pairs, win rates, volume traded

### 2. Risk Metrics  
**Analyzes**: How well your risk management works
**Uses**: `exit_reason`, `stop_loss_pct`, `profit_pct`
**Shows**: Stop-loss effectiveness, maximum drawdown, risk ratios

### 3. Strategy Performance
**Analyzes**: Which Freqtrade strategies work best
**Uses**: `strategy`, `profit_pct`, `profit_abs`
**Shows**: Strategy win rates, profit factors, consistency scores

### 4. Timing Analysis
**Analyzes**: When you should trade for best results
**Uses**: `open_date`, `trade_duration`, `profit_pct`
**Shows**: Best trading hours, weekend vs weekday performance

### 5. Pair Analytics
**Analyzes**: Individual currency pair performance
**Uses**: `pair`, `base_currency`, `quote_currency`, `profit_pct`
**Shows**: Per-pair statistics, volatility, trade patterns

### 6. Stop Loss Analytics
**Analyzes**: Stop-loss effectiveness by pair
**Uses**: `exit_reason`, `stop_loss_pct`, `pair`
**Shows**: How often stop-losses trigger, their effectiveness

### 7. Duration Patterns
**Analyzes**: How trade length affects profitability
**Uses**: `trade_duration`, `profit_pct`
**Shows**: Scalp vs swing trade performance, optimal hold times

### 8. Bot Health Metrics
**Analyzes**: Overall Freqtrade bot health
**Uses**: All trade data for aggregate metrics
**Shows**: Win rate, average profit, health status (HEALTHY/WARNING/CRITICAL)

## Real-time Monitoring Flow

```
1. Freqtrade executes strategy → Opens trade
2. Market conditions change → Freqtrade closes trade  
3. Trade Object updated → is_open = 0, profit calculated
4. Analytics system detects → New completed trade
5. All 8 categories updated → Fresh insights available
6. Health status evaluated → System status updated
```

## Example Freqtrade Integration

### Sample Strategy Impact
If you're running a Freqtrade strategy like:

```python
# freqtrade/user_data/strategies/MyStrategy.py
class MyStrategy(IStrategy):
    def populate_entry_trend(self, dataframe, metadata):
        # Your entry logic
        return dataframe
    
    def populate_exit_trend(self, dataframe, metadata):  
        # Your exit logic
        return dataframe
```

The analytics system will automatically track:
- How profitable "MyStrategy" is compared to others
- Which pairs work best with this strategy
- Optimal timing for this strategy
- Risk metrics specific to this strategy's trades

### Database Query Examples

**Check Freqtrade trades:**
```sql
SELECT 
    pair,
    strategy, 
    ROUND(close_profit * 100, 2) as profit_pct,
    exit_reason,
    open_date_utc,
    close_date_utc
FROM trades 
WHERE is_open = 0 
ORDER BY close_date_utc DESC 
LIMIT 10;
```

**Strategy performance:**
```sql
SELECT 
    strategy,
    COUNT(*) as total_trades,
    AVG(close_profit * 100) as avg_profit_pct,
    SUM(CASE WHEN close_profit > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as win_rate
FROM trades 
WHERE is_open = 0 
GROUP BY strategy;
```

## Troubleshooting Freqtrade Integration

### Database Not Found
```bash
# Find your Freqtrade database
find ~ -name "*.sqlite" | grep -i trade

# Check Freqtrade config for database location
cat ~/workspace/freqtrade_bot/config.json | grep db_url
```

### Schema Mismatch
```bash
# Compare schemas
sqlite3 ~/workspace/freqtrade_bot/user_data/tradesv3.sqlite ".schema"

# Update field mappings in trading_analytics_automation_final.py if needed
```

### No Trades Processing
```bash
# Verify trades exist and are closed  
sqlite3 ~/workspace/freqtrade_bot/user_data/tradesv3.sqlite \
  "SELECT COUNT(*), SUM(is_open), SUM(1-is_open) FROM trades"

# Should show: total_trades, open_trades, closed_trades
```

### Permission Issues
```bash
# Fix database permissions
chmod 644 ~/workspace/freqtrade_bot/user_data/tradesv3.sqlite

# Ensure directory is accessible
chmod 755 ~/workspace/freqtrade_bot/user_data/
```

## Advanced Integration

### Multiple Freqtrade Bots
If you run multiple Freqtrade instances:

```python
# Create separate analytics for each bot
bot1_analytics = TradingAnalyticsAutomator('~/bot1/user_data/tradesv3.sqlite')
bot2_analytics = TradingAnalyticsAutomator('~/bot2/user_data/tradesv3.sqlite')

# Run analysis on both
bot1_analytics.run_scheduled_analysis()
bot2_analytics.run_scheduled_analysis()
```

### Custom Database Paths
For non-standard Freqtrade setups:

```python
# Custom database location
custom_path = '/path/to/your/freqtrade/database.sqlite'
automator = TradingAnalyticsAutomator(custom_path)
```

### Integration with Freqtrade Web UI
The analytics complement Freqtrade's built-in web interface:
- **Freqtrade UI**: Real-time trading status, open positions
- **Analytics System**: Historical performance, deep insights, health monitoring

## Benefits for Freqtrade Users

### Automated Insights
- No manual report generation
- Real-time updates as trades complete
- Comprehensive analytics beyond basic P&L

### Strategy Optimization
- Compare strategy performance objectively
- Identify best-performing pairs per strategy
- Optimize entry/exit timing

### Risk Management
- Monitor stop-loss effectiveness
- Track maximum drawdown
- Health status alerts

### Performance Tracking
- Detailed pair analytics
- Duration pattern analysis
- Timing optimization insights

---

**Integration Status**: ✅ Fully Compatible with Freqtrade  
**Supported Versions**: Freqtrade v2023.1+  
**Database Format**: SQLite tradesv3.sqlite  
**Update Frequency**: Real-time (5-minute checks)  
**Last Updated**: 2025-07-30