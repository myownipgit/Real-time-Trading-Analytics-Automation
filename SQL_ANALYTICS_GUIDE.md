# SQL Analytics Guide: Real-time Trading Analytics Automation System

## Overview

This system includes 8 comprehensive SQL analytics files that provide deep insights into your trading performance. Each SQL file contains complete table schemas, data population queries, analysis examples, and maintenance scripts.

## 📊 Analytics Categories

### 1. Performance Rankings (`sql/performance_rankings.sql`)

**Purpose:** Ranks trading pairs by profitability to identify top performers

**Business Questions Answered:**
- Which trading pairs should I allocate more capital to?
- What's my portfolio's overall performance distribution?
- Which pairs have the best risk-adjusted returns?

**Key Tables Created:**
- `performance_rankings` - Main rankings by pairs, strategies, etc.

**Example Insights:**
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

---

### 2. Risk Metrics (`sql/risk_metrics.sql`)

**Purpose:** Tracks risk management effectiveness and portfolio safety

**Business Questions Answered:**
- Are my stop-losses working effectively?
- What's my maximum potential loss (Value at Risk)?
- Which pairs/strategies have the best risk-adjusted returns?

**Key Tables Created:**
- `risk_metrics` - Risk analysis by overall, pair, and strategy

**Example Insights:**
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

---

### 3. Strategy Performance (`sql/strategy_performance.sql`)

**Purpose:** Compares different trading strategies to optimize bot configuration

**Business Questions Answered:**
- Which strategies should I prioritize or disable?
- What's the risk-adjusted performance of each strategy?
- How consistent are my strategies over time?

**Key Tables Created:**
- `strategy_performance` - Comprehensive strategy comparison metrics

**Example Insights:**
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
    avg_duration_min,
    (avg_profit_pct / (avg_trade_duration_minutes / 60.0)) as profit_per_hour
FROM strategy_performance 
WHERE avg_trade_duration_minutes > 0
ORDER BY profit_per_hour DESC;
```

---

### 4. Timing Analysis (`sql/timing_analysis.sql`)

**Purpose:** Identifies optimal trading times and market session performance

**Business Questions Answered:**
- When should I schedule my bot to trade for maximum profit?
- Do weekends perform differently than weekdays?
- Which market sessions (US, EU, Asia) are most profitable?

**Key Tables Created:**
- `timing_analysis` - Time-based performance analysis

**Example Insights:**
```sql
-- Best trading hours
SELECT 
    hour_of_day,
    time_period_name,
    trade_count,
    win_rate_pct,
    avg_profit_pct
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
    AVG(avg_profit_pct) as session_avg_profit
FROM timing_analysis 
WHERE time_category = 'hourly'
GROUP BY market_session
ORDER BY session_avg_profit DESC;
```

---

### 5. Pair Analytics (`sql/pair_analytics.sql`)

**Purpose:** Deep-dive analysis of individual currency pair behavior and characteristics

**Business Questions Answered:**
- How should I tailor my trading approach to each pair?
- Which pairs prefer short-term vs long-term trades?
- What are the volatility patterns for each pair?

**Key Tables Created:**
- `pair_analytics` - Individual pair performance and characteristics

**Example Insights:**
```sql
-- Most consistent pairs (low volatility, good performance)
SELECT 
    pair,
    avg_profit_pct,
    price_volatility_pct,
    win_rate * 100 as win_rate_pct,
    sharpe_ratio
FROM pair_analytics 
WHERE total_trades >= 5 AND avg_profit_pct > 0
ORDER BY sharpe_ratio DESC, price_volatility_pct ASC;

-- Base currency performance analysis
SELECT 
    base_currency,
    COUNT(*) as pair_count,
    AVG(avg_profit_pct) as avg_profit,
    AVG(win_rate * 100) as avg_win_rate,
    SUM(total_profit_abs) as total_profit
FROM pair_analytics 
GROUP BY base_currency
HAVING pair_count >= 2
ORDER BY avg_profit DESC;
```

---

### 6. Stop Loss Analytics (`sql/stop_loss_analytics.sql`)

**Purpose:** Optimizes stop-loss levels and analyzes protection effectiveness

**Business Questions Answered:**
- Are my stop-loss levels too tight or too loose?
- Which pairs/strategies need stop-loss optimization?
- How much money are my stop-losses saving vs costing?

**Key Tables Created:**
- `stop_loss_analytics` - Stop-loss effectiveness analysis

**Example Insights:**
```sql
-- Stop-loss effectiveness by pair
SELECT 
    pair,
    sl_trigger_rate_pct,
    sl_effectiveness_pct,
    avg_sl_level_pct,
    optimal_sl_level_pct,
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
    AVG(sl_effectiveness_pct) as avg_effectiveness,
    AVG(sl_trigger_rate_pct) as avg_trigger_rate
FROM stop_loss_analytics 
WHERE analysis_type = 'by_pair'
GROUP BY sl_level_category
ORDER BY avg_effectiveness DESC;
```

---

### 7. Duration Patterns (`sql/duration_patterns.sql`)

**Purpose:** Analyzes trade duration patterns to optimize exit timing strategies

**Business Questions Answered:**
- Which trade durations are most profitable per hour?
- Should I focus on scalping, day trading, or swing trading?
- What are the optimal exit timings for each pair?

**Key Tables Created:**
- `duration_patterns` - Trade duration analysis and efficiency metrics

**Example Insights:**
```sql
-- Duration category efficiency
SELECT 
    duration_category,
    trade_count,
    avg_profit_pct,
    profit_per_hour,
    optimal_exit_timing_minutes / 60.0 as avg_duration_hours
FROM duration_patterns 
WHERE pattern_type = 'duration_based'
ORDER BY profit_per_hour DESC;

-- Optimal duration by pair
SELECT 
    pair,
    duration_category,
    profit_per_hour,
    win_rate * 100 as win_rate_pct,
    optimal_exit_timing_minutes
FROM duration_patterns 
WHERE pattern_type = 'by_pair'
  AND trade_count >= 3
ORDER BY pair, profit_per_hour DESC;
```

---

### 8. Bot Health Metrics (`sql/bot_health_metrics.sql`)

**Purpose:** Comprehensive system health monitoring with automated alerts

**Business Questions Answered:**
- Is my trading bot performing well overall?
- Which metrics need immediate attention?
- Am I properly diversified across pairs and strategies?

**Key Tables Created:**
- `bot_health_metrics` - System health indicators with thresholds

**Example Insights:**
```sql
-- Overall health dashboard
SELECT 
    metric_name,
    metric_value,
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
    COUNT(CASE WHEN health_status = 'HEALTHY' THEN 1 END) * 100.0 / COUNT(*) as health_score_pct,
    COUNT(CASE WHEN health_status = 'CRITICAL' THEN 1 END) as critical_alerts,
    COUNT(CASE WHEN health_status = 'WARNING' THEN 1 END) as warning_alerts
FROM bot_health_metrics;
```

## 🔧 Using the SQL Files

### Automated Execution
The trading automation system automatically executes these SQL files when new trades complete. You don't need to run them manually unless you want to refresh the data.

### Manual Execution
```bash
# Run all analytics
for sql_file in sql/*.sql; do
    echo "Processing $sql_file..."
    sqlite3 ~/db_dev/trading_test.db < "$sql_file"
done

# Run specific analytics
sqlite3 ~/db_dev/trading_test.db < sql/performance_rankings.sql
sqlite3 ~/db_dev/trading_test.db < sql/timing_analysis.sql
```

### Custom Analysis
Each SQL file includes:
- **Table creation** scripts with proper indexing
- **Data population** queries for automation
- **Example queries** for analysis
- **Maintenance queries** for data quality

### Advanced Usage
```bash
# Interactive analysis
sqlite3 ~/db_dev/trading_test.db

# Export results to CSV
sqlite3 -header -csv ~/db_dev/trading_test.db "SELECT * FROM performance_rankings" > performance_report.csv

# Create custom reports
sqlite3 ~/db_dev/trading_test.db "
.mode column
.headers on
SELECT 
    pr.entity_name as pair,
    pr.profit_pct,
    rm.volatility_pct,
    ta.best_performance_hour
FROM performance_rankings pr
JOIN risk_metrics rm ON pr.entity_name = rm.entity_name
JOIN timing_analysis ta ON ta.time_category = 'overall'
WHERE pr.ranking_type = 'by_pair'
ORDER BY pr.profit_pct DESC
LIMIT 10;
"
```

## 📈 Business Impact

### Capital Allocation
Use Performance Rankings and Pair Analytics to:
- Allocate more capital to top-performing pairs
- Reduce exposure to underperforming assets
- Balance portfolio based on volatility and returns

### Risk Management
Use Risk Metrics and Stop Loss Analytics to:
- Optimize stop-loss levels per pair
- Monitor portfolio-wide risk exposure
- Prevent catastrophic losses

### Strategy Optimization
Use Strategy Performance and Duration Patterns to:
- Prioritize winning strategies
- Optimize trade duration for maximum efficiency
- Adjust bot configuration based on performance

### Operational Excellence
Use Timing Analysis and Bot Health Metrics to:
- Schedule trading during optimal hours
- Monitor system health proactively
- Maintain consistent trading performance

## 🚨 Alert System

The Bot Health Metrics provide automated alerts:

- **CRITICAL**: Requires immediate attention (win rate <40% or losing money)
- **WARNING**: Needs monitoring (win rate 40-60% or minimal profits)
- **HEALTHY**: System performing well (win rate >60% and profitable)

Monitor these alerts daily to maintain optimal trading performance.

---

**Next Steps:**
1. Review your current analytics by running the SQL queries
2. Identify optimization opportunities from the insights
3. Adjust your trading bot configuration accordingly
4. Monitor the Bot Health Metrics for ongoing performance