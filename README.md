# Real-time Trading Analytics Automation System

## System Overview

This system provides **automated real-time analytics** for your [Freqtrade](https://github.com/freqtrade/freqtrade) cryptocurrency trading bot, processing completed trades and updating 8 comprehensive analytics categories automatically.

**🤖 Freqtrade Integration**: Monitors your Freqtrade database (`~/workspace/freqtrade_bot/user_data/tradesv3.sqlite`) and generates insights from your trading bot's performance in real-time.

📖 **[Complete User Guide](USER_GUIDE.md)** | 🔗 **[Freqtrade Integration Guide](FREQTRADE_INTEGRATION.md)** | 📊 **[SQL Analytics Guide](SQL_ANALYTICS_GUIDE.md)**

## 🚀 Quick Start

### Start the System
```bash
./start_production.sh
```

### Check Status
```bash
./check_status.sh
```

### Stop the System
```bash
./stop_production.sh
```

## 📊 Analytics Categories

The system automatically updates these 8 analytics categories when new trades complete, each with dedicated SQL files in the `/sql/` directory:

### 1. Performance Rankings
- **Table**: `performance_rankings` | **SQL**: `sql/performance_rankings.sql`
- **Purpose**: Ranks trading pairs by profitability to identify top performers
- **Key Metrics**: Win rate, profit percentage, trade count, profit ratios, volume analysis
- **Business Value**: Identifies which trading pairs generate the most profit and should receive more capital allocation
- **Example Insights**: "HYPER/USDT has 100% win rate with 3.04% average profit - allocate more funds"

### 2. Risk Metrics
- **Table**: `risk_metrics` | **SQL**: `sql/risk_metrics.sql`
- **Purpose**: Tracks risk management effectiveness and portfolio safety
- **Key Metrics**: Stop-loss triggers, effectiveness percentages, drawdown, Value at Risk (VaR)
- **Business Value**: Prevents catastrophic losses by monitoring risk levels and stop-loss performance
- **Example Insights**: "Stop-loss effectiveness is 85% - risk management working well"

### 3. Strategy Performance
- **Table**: `strategy_performance` | **SQL**: `sql/strategy_performance.sql`
- **Purpose**: Compares different trading strategies to optimize bot configuration
- **Key Metrics**: Win rates, profit factors, expectancy, Sharpe ratios, consecutive streaks
- **Business Value**: Determines which strategies work best and should be prioritized or disabled
- **Example Insights**: "SampleStrategy outperforms with 93.94% win rate - increase allocation"

### 4. Timing Analysis
- **Table**: `timing_analysis` | **SQL**: `sql/timing_analysis.sql`
- **Purpose**: Identifies optimal trading times and market session performance
- **Key Metrics**: Hourly performance, weekend vs weekday, market session analysis, best/worst hours
- **Business Value**: Optimizes trading schedules to trade during profitable hours and avoid poor periods
- **Example Insights**: "Best performance at 14:00-16:00 UTC, worst at 02:00-04:00 UTC"

### 5. Pair Analytics
- **Table**: `pair_analytics` | **SQL**: `sql/pair_analytics.sql`
- **Purpose**: Deep-dive analysis of individual currency pair behavior and characteristics
- **Key Metrics**: Volatility patterns, duration preferences, base/quote currency analysis, efficiency ratios
- **Business Value**: Tailors trading approach per pair based on their unique characteristics
- **Example Insights**: "BTC pairs prefer short-term trades, ETH pairs perform better in swing trades"

### 6. Stop Loss Analytics
- **Table**: `stop_loss_analytics` | **SQL**: `sql/stop_loss_analytics.sql`
- **Purpose**: Optimizes stop-loss levels and analyzes protection effectiveness
- **Key Metrics**: Trigger rates, effectiveness percentages, optimal levels, loss prevention analysis
- **Business Value**: Fine-tunes risk management by optimizing stop-loss levels per pair/strategy
- **Example Insights**: "Current -5% stop-loss too tight for HYPER/USDT, optimal level is -3%"

### 7. Duration Patterns
- **Table**: `duration_patterns` | **SQL**: `sql/duration_patterns.sql`
- **Purpose**: Analyzes trade duration patterns to optimize exit timing strategies
- **Key Metrics**: Scalp/short-term/day-trade/swing-trade performance, profit-per-hour efficiency
- **Business Value**: Maximizes profit efficiency by identifying optimal trade duration ranges
- **Example Insights**: "Short-term trades (1-8h) generate 2.3x more profit per hour than swing trades"

### 8. Bot Health Metrics
- **Table**: `bot_health_metrics` | **SQL**: `sql/bot_health_metrics.sql`
- **Purpose**: Comprehensive system health monitoring with automated alerts
- **Key Metrics**: Health status (HEALTHY/WARNING/CRITICAL), performance thresholds, diversification metrics
- **Business Value**: Provides early warning system for performance degradation and system issues
- **Example Insights**: "Win rate dropped to 45% - WARNING status triggered, review strategy performance"

## 🔧 SQL Analytics System

Each analytics category includes:

- **Complete table schemas** with proper indexing for performance
- **Data population queries** compatible with `~/db_dev/trading_test.db`
- **Analysis examples** and query templates
- **Maintenance scripts** for data quality and cleanup
- **Direct trades table queries** for real-time analysis

### SQL File Usage
```bash
# Execute specific analytics category
sqlite3 ~/db_dev/trading_test.db < sql/performance_rankings.sql

# Run all analytics (executed automatically by system)
for sql_file in sql/*.sql; do
    sqlite3 ~/db_dev/trading_test.db < "$sql_file"
done
```

### Analytics Data Flow
1. **Freqtrade** completes trades → `tradesv3.sqlite`
2. **Analytics System** detects new trades → processes updates
3. **SQL Scripts** populate analytics tables → generates insights
4. **Health Monitoring** evaluates metrics → triggers alerts
5. **User Queries** access insights → inform trading decisions

## 🏥 Health Status System

The system automatically determines health status based on:

- **HEALTHY**: Win rate ≥70% AND average profit ≥0.5%
- **WARNING**: Win rate ≥50% AND average profit ≥0%
- **CRITICAL**: Below warning thresholds

## 🔧 Technical Details

### Database Integration
- **Primary Database**: `~/workspace/freqtrade_bot/user_data/tradesv3.sqlite` (Freqtrade database)
- **Access Method**: Direct SQLite connection
- **Data Source**: Freqtrade Trade Objects stored in SQLite
- **MCP Server**: `sqlite-trading-test` for external access

### Automation Schedule
- **Trade Checks**: Every 5 minutes
- **Health Checks**: Every hour
- **Processing**: Only when new completed trades detected

### Logging
- **File**: `trading_analytics.log`
- **Console**: Real-time output
- **Format**: Timestamp, level, message

## 📈 Current Performance

Based on your 90 completed trades:

- **Overall Win Rate**: 86.67% (HEALTHY)
- **Average Profit**: 0.73% (HEALTHY)
- **Total Profit**: $39.03
- **Best Strategy**: SampleStrategy (93.94% win rate, 1.18% avg profit)
- **Top Performing Pair**: HYPER/USDT (3.04% avg profit, 100% win rate)

## 🔍 Monitoring Commands

### View Live Logs
```bash
tail -f trading_analytics.log
```

### Attach to Running Session
```bash
screen -r trading_analytics
```

### Query Analytics Data
```bash
# Top performing pairs
sqlite3 ~/db_dev/trading_test.db "
SELECT entity_name, profit_pct, win_rate, trade_count 
FROM performance_rankings 
ORDER BY profit_pct DESC LIMIT 10"

# Strategy comparison
sqlite3 ~/db_dev/trading_test.db "
SELECT strategy_name, win_rate, avg_profit_pct, total_trades 
FROM strategy_performance 
ORDER BY avg_profit_pct DESC"

# Health status
sqlite3 ~/db_dev/trading_test.db "
SELECT metric_name, metric_value, health_status 
FROM bot_health_metrics"
```

## 📁 Files Structure

```
├── trading_analytics_automation_final.py  # Main automation engine
├── start_production.sh                    # Production starter
├── stop_production.sh                     # Production stopper  
├── check_status.sh                        # Status checker
├── trading_analytics.log                  # System logs
├── venv_analytics/                        # Python virtual environment
└── CLAUDE.md                             # Development guide
```

## 🐛 Troubleshooting

### System Not Starting
1. Check virtual environment: `source venv_analytics/bin/activate`
2. Verify database access: `sqlite3 ~/db_dev/trading_test.db ".tables"`
3. Check dependencies: `pip list | grep schedule`

### No New Trades Processing
- System only processes trades with `is_open = 0`
- Tracks last processed trade ID to avoid duplicates
- Check `analysis_snapshots` table for processing history

### Performance Issues
- System uses efficient SQL queries with proper indexing
- Clears and recalculates analytics tables for consistency
- Monitors resource usage via status scripts

## 🔄 Continuous Operation

The system is designed for 24/7 operation:

- **Automatic Recovery**: Handles database connection errors gracefully
- **State Persistence**: Tracks last processed trade ID across restarts
- **Resource Efficient**: Only processes when new trades are detected
- **Error Logging**: Comprehensive error tracking and reporting

## 📞 Support

For issues or questions:
1. Check logs: `tail -f trading_analytics.log`
2. Verify status: `./check_status.sh`
3. Review database: Query analytics tables directly
4. Restart system: `./stop_production.sh && ./start_production.sh`

---

**System Status**: ✅ Ready for Production Deployment
**Last Updated**: 2025-07-30
**Trades Processed**: 90 completed trades
**Analytics Health**: All 8 categories operational