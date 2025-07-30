# API Documentation

## Core Class: TradingAnalyticsAutomator

### Constructor

```python
TradingAnalyticsAutomator(analytics_db_path=None)
```

**Parameters:**
- `analytics_db_path` (str, optional): Path to SQLite database. Defaults to `~/db_dev/trading_test.db`

### Methods

#### run_scheduled_analysis()
Executes a complete analysis cycle, checking for new trades and updating all analytics.

```python
automator.run_scheduled_analysis()
```

#### start_automation()
Starts the continuous automation loop with scheduled checks every 5 minutes.

```python
automator.start_automation()
```

## Analytics Update Methods

### update_performance_rankings(conn)
Updates trading pair performance rankings.

**Metrics Calculated:**
- Profit ratio and percentage
- Win rate
- Trade count
- Average duration
- Volume metrics

### update_risk_metrics(conn)
Calculates risk management effectiveness.

**Metrics Calculated:**
- Stop-loss trigger counts
- Stop-loss effectiveness percentage
- Maximum drawdown
- Sharpe ratio (simplified)

### update_strategy_performance(conn)
Compares different trading strategies.

**Metrics Calculated:**
- Win/loss counts
- Profit factors
- Expectancy
- Consistency scores

### update_timing_analysis(conn)
Analyzes performance by time patterns.

**Metrics Calculated:**
- Best/worst performance hours
- Weekend vs weekday performance
- Average durations by time

### update_pair_analytics(conn)
Individual currency pair analysis.

**Metrics Calculated:**
- Trade counts by pair
- Win rates
- Volatility scores
- Average durations

### update_stop_loss_analytics(conn)
Stop-loss effectiveness analysis.

**Metrics Calculated:**
- Stop-loss trigger rates
- Average losses when triggered
- Effectiveness scores by pair

### update_duration_patterns(conn)
Trade duration pattern analysis.

**Categories:**
- Scalp: ≤60 minutes
- Short-term: ≤480 minutes
- Day trade: ≤1440 minutes
- Swing trade: >1440 minutes

### update_bot_health_metrics(conn)
Overall system health monitoring.

**Health Status Logic:**
- HEALTHY: Win rate ≥70% AND avg profit ≥0.5%
- WARNING: Win rate ≥50% AND avg profit ≥0%
- CRITICAL: Below warning thresholds

## Database Schema

### analysis_snapshots
Tracks automation execution history.

```sql
CREATE TABLE analysis_snapshots (
    id INTEGER PRIMARY KEY,
    snapshot_type TEXT,
    records_processed INTEGER,
    status TEXT,
    last_trade_id INTEGER,
    last_analysis_run DATETIME,
    error_message TEXT
);
```

### performance_rankings
Stores entity performance rankings.

```sql
CREATE TABLE performance_rankings (
    id INTEGER PRIMARY KEY,
    ranking_type TEXT,
    entity_name TEXT,
    entity_type TEXT,
    profit_ratio REAL,
    profit_pct REAL,
    profit_abs REAL,
    trade_count INTEGER,
    win_rate REAL,
    avg_duration_minutes REAL,
    max_profit_pct REAL,
    min_profit_pct REAL,
    total_volume REAL,
    rank_position INTEGER,
    analysis_date DATETIME
);
```

## Usage Examples

### Basic Usage

```python
from trading_analytics_automation_final import TradingAnalyticsAutomator

# Initialize
automator = TradingAnalyticsAutomator()

# Run single analysis
automator.run_scheduled_analysis()
```

### Custom Database Path

```python
automator = TradingAnalyticsAutomator('/path/to/custom/database.db')
```

### Programmatic Health Check

```python
import sqlite3

def check_bot_health():
    conn = sqlite3.connect('~/db_dev/trading_test.db')
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT metric_name, metric_value, health_status
        FROM bot_health_metrics
        WHERE metric_name = 'overall_win_rate'
    """)
    
    result = cursor.fetchone()
    if result:
        print(f"Win Rate: {result[1]}% - Status: {result[2]}")
    
    conn.close()
```

### Query Top Performers

```python
def get_top_pairs(limit=5):
    conn = sqlite3.connect('~/db_dev/trading_test.db')
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT entity_name, profit_pct, win_rate, trade_count
        FROM performance_rankings
        WHERE ranking_type = 'by_pair'
        ORDER BY profit_pct DESC
        LIMIT ?
    """, (limit,))
    
    results = cursor.fetchall()
    conn.close()
    
    return results
```

## Error Handling

The system includes comprehensive error handling:

1. **Database Connection Errors**: Logged and gracefully handled
2. **Processing Errors**: Tracked in analysis_snapshots with error messages
3. **Scheduling Errors**: Caught and logged without stopping the system

## Performance Considerations

- Uses efficient SQL queries with proper indexing
- Processes only new trades (incremental updates)
- Clears and recalculates tables for consistency
- 30-second polling interval for scheduled jobs

## Integration Points

### MCP Server Access
The database can be accessed via MCP server `sqlite-trading-test` for external integrations.

### Direct Database Access
All analytics tables can be queried directly using standard SQLite tools.

### Log Monitoring
System logs can be monitored in real-time:
```bash
tail -f trading_analytics.log
```