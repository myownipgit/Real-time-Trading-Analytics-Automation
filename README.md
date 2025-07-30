# Real-time Trading Analytics Automation System

## System Overview

This system provides **automated real-time analytics** for your trading bot, processing completed trades and updating 8 comprehensive analytics categories automatically.

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

The system automatically updates these 8 analytics categories when new trades complete:

### 1. Performance Rankings
- **Table**: `performance_rankings`
- **Purpose**: Ranks trading pairs by profitability
- **Key Metrics**: Win rate, profit percentage, trade count, profit ratios

### 2. Risk Metrics
- **Table**: `risk_metrics`
- **Purpose**: Tracks risk management effectiveness
- **Key Metrics**: Stop-loss triggers, effectiveness percentages, drawdown

### 3. Strategy Performance
- **Table**: `strategy_performance`
- **Purpose**: Compares different trading strategies
- **Key Metrics**: Win rates, profit factors, expectancy, consistency scores

### 4. Timing Analysis
- **Table**: `timing_analysis`
- **Purpose**: Identifies optimal trading times
- **Key Metrics**: Best/worst performance hours, weekend vs weekday performance

### 5. Pair Analytics
- **Table**: `pair_analytics`
- **Purpose**: Individual currency pair performance analysis
- **Key Metrics**: Trade counts, win rates, volatility scores, duration patterns

### 6. Stop Loss Analytics
- **Table**: `stop_loss_analytics`
- **Purpose**: Stop-loss effectiveness by pair and strategy
- **Key Metrics**: Trigger rates, effectiveness percentages, optimal levels

### 7. Duration Patterns
- **Table**: `duration_patterns`
- **Purpose**: Trade duration optimization
- **Key Metrics**: Scalp/short-term/day-trade/swing-trade performance

### 8. Bot Health Metrics
- **Table**: `bot_health_metrics`
- **Purpose**: Overall system health monitoring
- **Key Metrics**: Health status (HEALTHY/WARNING/CRITICAL), key performance indicators

## 🏥 Health Status System

The system automatically determines health status based on:

- **HEALTHY**: Win rate ≥70% AND average profit ≥0.5%
- **WARNING**: Win rate ≥50% AND average profit ≥0%
- **CRITICAL**: Below warning thresholds

## 🔧 Technical Details

### Database Integration
- **Primary Database**: `~/db_dev/trading_test.db`
- **Access Method**: Direct SQLite connection
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