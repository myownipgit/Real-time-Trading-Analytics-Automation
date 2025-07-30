-- Bot Health Metrics SQL
-- Purpose: Overall system health monitoring and performance tracking
-- Data Source: ~/db_dev/trading_test.db trades table
-- Key Metrics: System health status, performance thresholds, alerts

-- =====================================================
-- 1. CREATE TABLE: bot_health_metrics
-- =====================================================

CREATE TABLE IF NOT EXISTS bot_health_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_name TEXT NOT NULL,              -- Name of the health metric
    metric_value REAL,                      -- Current value of the metric
    metric_unit TEXT,                       -- Unit of measurement (%, count, abs, etc.)
    health_status TEXT,                     -- 'HEALTHY', 'WARNING', 'CRITICAL'
    threshold_warning REAL,                 -- Warning threshold value
    threshold_critical REAL,               -- Critical threshold value
    last_calculation DATETIME,             -- When this metric was last calculated
    analysis_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Additional context fields
    metric_description TEXT,               -- Description of what this metric tracks
    recommendation TEXT,                   -- Recommended action if thresholds exceeded
    
    -- Indexes for performance
    UNIQUE(metric_name)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_bot_health_metrics_name ON bot_health_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_bot_health_metrics_status ON bot_health_metrics(health_status);
CREATE INDEX IF NOT EXISTS idx_bot_health_metrics_date ON bot_health_metrics(analysis_date);

-- =====================================================
-- 2. POPULATE TABLE: Core Bot Health Metrics
-- =====================================================

-- Clear existing metrics and recalculate
DELETE FROM bot_health_metrics;

-- Get overall trading statistics for health calculation
WITH trading_stats AS (
    SELECT 
        COUNT(*) as total_trades,
        AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
        AVG(profit_pct) as avg_profit_pct,
        SUM(profit_abs) as total_profit,
        MIN(profit_pct) as worst_loss,
        MAX(profit_pct) as best_win,
        COUNT(DISTINCT pair) as pairs_traded,
        COUNT(DISTINCT strategy) as strategies_used,
        AVG(trade_duration) as avg_duration_minutes,
        SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as sl_triggered,
        COUNT(DISTINCT DATE(open_date)) as active_trading_days,
        MAX(julianday(open_date)) - MIN(julianday(open_date)) as total_trading_period_days
    FROM trades 
    WHERE is_open = 0
)
INSERT INTO bot_health_metrics (
    metric_name, metric_value, metric_unit, health_status, 
    threshold_warning, threshold_critical, metric_description,
    recommendation, analysis_date
)
SELECT * FROM (
    -- Overall Win Rate
    SELECT 
        'overall_win_rate' as metric_name,
        win_rate * 100 as metric_value,
        '%' as metric_unit,
        CASE 
            WHEN win_rate >= 0.6 THEN 'HEALTHY'
            WHEN win_rate >= 0.4 THEN 'WARNING'
            ELSE 'CRITICAL'
        END as health_status,
        60.0 as threshold_warning,
        40.0 as threshold_critical,
        'Percentage of profitable trades' as metric_description,
        'Review strategy performance if below 60%' as recommendation,
        CURRENT_TIMESTAMP as analysis_date
    FROM trading_stats
    
    UNION ALL
    
    -- Average Profit Percentage
    SELECT 
        'average_profit_pct' as metric_name,
        avg_profit_pct as metric_value,
        '%' as metric_unit,
        CASE 
            WHEN avg_profit_pct >= 0.5 THEN 'HEALTHY'
            WHEN avg_profit_pct >= 0.0 THEN 'WARNING'
            ELSE 'CRITICAL'
        END as health_status,
        0.5 as threshold_warning,
        0.0 as threshold_critical,
        'Average profit percentage per trade' as metric_description,
        'Optimize strategies if below 0.5%' as recommendation,
        CURRENT_TIMESTAMP as analysis_date
    FROM trading_stats
    
    UNION ALL
    
    -- Total Trades Count
    SELECT 
        'total_trades' as metric_name,
        total_trades as metric_value,
        'count' as metric_unit,
        CASE 
            WHEN total_trades >= 50 THEN 'HEALTHY'
            WHEN total_trades >= 10 THEN 'WARNING'
            ELSE 'CRITICAL'
        END as health_status,
        50.0 as threshold_warning,
        10.0 as threshold_critical,
        'Total number of completed trades' as metric_description,
        'Increase trading frequency if below threshold' as recommendation,
        CURRENT_TIMESTAMP as analysis_date
    FROM trading_stats
    
    UNION ALL
    
    -- Total Profit
    SELECT 
        'total_profit_abs' as metric_name,
        total_profit as metric_value,
        'abs' as metric_unit,
        CASE 
            WHEN total_profit >= 100 THEN 'HEALTHY'
            WHEN total_profit >= 0 THEN 'WARNING'
            ELSE 'CRITICAL'
        END as health_status,
        100.0 as threshold_warning,
        0.0 as threshold_critical,
        'Total absolute profit generated' as metric_description,
        'Review strategy allocation if unprofitable' as recommendation,
        CURRENT_TIMESTAMP as analysis_date
    FROM trading_stats
    
    UNION ALL
    
    -- Worst Loss Control
    SELECT 
        'worst_loss_control' as metric_name,
        worst_loss as metric_value,
        '%' as metric_unit,
        CASE 
            WHEN worst_loss > -10 THEN 'HEALTHY'
            WHEN worst_loss > -20 THEN 'WARNING'
            ELSE 'CRITICAL'
        END as health_status,
        -10.0 as threshold_warning,
        -20.0 as threshold_critical,
        'Largest single trade loss percentage' as metric_description,
        'Review risk management if losses exceed -10%' as recommendation,
        CURRENT_TIMESTAMP as analysis_date
    FROM trading_stats
    
    UNION ALL
    
    -- Best Win Achievement
    SELECT 
        'best_win_achievement' as metric_name,
        best_win as metric_value,
        '%' as metric_unit,
        'HEALTHY' as health_status,
        5.0 as threshold_warning,
        2.0 as threshold_critical,
        'Largest single trade profit percentage' as metric_description,
        'Excellent profit capture capability' as recommendation,
        CURRENT_TIMESTAMP as analysis_date
    FROM trading_stats
    
    UNION ALL
    
    -- Portfolio Diversification
    SELECT 
        'portfolio_diversification' as metric_name,
        pairs_traded as metric_value,
        'count' as metric_unit,
        CASE 
            WHEN pairs_traded >= 5 THEN 'HEALTHY'
            WHEN pairs_traded >= 3 THEN 'WARNING'
            ELSE 'CRITICAL'
        END as health_status,
        5.0 as threshold_warning,
        3.0 as threshold_critical,
        'Number of different trading pairs used' as metric_description,
        'Increase diversification if below 5 pairs' as recommendation,
        CURRENT_TIMESTAMP as analysis_date
    FROM trading_stats
    
    UNION ALL
    
    -- Strategy Utilization
    SELECT 
        'strategy_utilization' as metric_name,
        strategies_used as metric_value,
        'count' as metric_unit,
        CASE 
            WHEN strategies_used >= 3 THEN 'HEALTHY'
            WHEN strategies_used >= 2 THEN 'WARNING'
            ELSE 'CRITICAL'
        END as health_status,
        3.0 as threshold_warning,
        2.0 as threshold_critical,
        'Number of different strategies deployed' as metric_description,
        'Consider multi-strategy approach for better risk distribution' as recommendation,
        CURRENT_TIMESTAMP as analysis_date
    FROM trading_stats
    
    UNION ALL
    
    -- Average Trade Duration Efficiency
    SELECT 
        'trade_duration_efficiency' as metric_name,
        avg_duration_minutes as metric_value,
        'minutes' as metric_unit,
        CASE 
            WHEN avg_duration_minutes <= 480 THEN 'HEALTHY'
            WHEN avg_duration_minutes <= 1440 THEN 'WARNING'
            ELSE 'CRITICAL'
        END as health_status,
        480.0 as threshold_warning,
        1440.0 as threshold_critical,
        'Average trade duration in minutes' as metric_description,
        'Consider faster exit strategies if duration exceeds 8 hours' as recommendation,
        CURRENT_TIMESTAMP as analysis_date
    FROM trading_stats
    
    UNION ALL
    
    -- Stop Loss Utilization Rate
    SELECT 
        'stop_loss_utilization_rate' as metric_name,
        (sl_triggered * 100.0 / NULLIF(total_trades, 0)) as metric_value,
        '%' as metric_unit,
        CASE 
            WHEN (sl_triggered * 100.0 / NULLIF(total_trades, 0)) <= 20 THEN 'HEALTHY'
            WHEN (sl_triggered * 100.0 / NULLIF(total_trades, 0)) <= 40 THEN 'WARNING'
            ELSE 'CRITICAL'
        END as health_status,
        20.0 as threshold_warning,
        40.0 as threshold_critical,
        'Percentage of trades exited via stop loss' as metric_description,
        'Review stop loss levels if trigger rate exceeds 20%' as recommendation,
        CURRENT_TIMESTAMP as analysis_date
    FROM trading_stats
    
    UNION ALL
    
    -- Trading Activity Consistency
    SELECT 
        'trading_activity' as metric_name,
        CASE 
            WHEN total_trading_period_days > 0 
            THEN (active_trading_days * 100.0 / total_trading_period_days)
            ELSE 0 
        END as metric_value,
        '%' as metric_unit,
        CASE 
            WHEN total_trading_period_days > 0 AND (active_trading_days * 100.0 / total_trading_period_days) >= 50 THEN 'HEALTHY'
            WHEN total_trading_period_days > 0 AND (active_trading_days * 100.0 / total_trading_period_days) >= 25 THEN 'WARNING'
            ELSE 'CRITICAL'
        END as health_status,
        50.0 as threshold_warning,
        25.0 as threshold_critical,
        'Percentage of days with trading activity' as metric_description,
        'Increase trading consistency if below 50%' as recommendation,
        CURRENT_TIMESTAMP as analysis_date
    FROM trading_stats
);

-- =====================================================
-- 3. QUERY EXAMPLES: Bot Health Dashboard
-- =====================================================

-- Overall health status dashboard
SELECT 
    metric_name,
    ROUND(metric_value, 2) as current_value,
    metric_unit,
    health_status,
    CASE 
        WHEN threshold_warning IS NOT NULL THEN ROUND(threshold_warning, 2)
        ELSE NULL 
    END as warning_threshold,
    CASE 
        WHEN threshold_critical IS NOT NULL THEN ROUND(threshold_critical, 2)
        ELSE NULL 
    END as critical_threshold,
    metric_description
FROM bot_health_metrics 
ORDER BY 
    CASE health_status 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'WARNING' THEN 2 
        WHEN 'HEALTHY' THEN 3 
    END,
    metric_name;

-- Health status summary
SELECT 
    health_status,
    COUNT(*) as metric_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM bot_health_metrics), 1) as percentage_of_metrics
FROM bot_health_metrics 
GROUP BY health_status
ORDER BY 
    CASE health_status 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'WARNING' THEN 2 
        WHEN 'HEALTHY' THEN 3 
    END;

-- Critical and warning metrics requiring attention
SELECT 
    metric_name,
    ROUND(metric_value, 2) as current_value,
    metric_unit,
    health_status,
    recommendation,
    CASE 
        WHEN health_status = 'CRITICAL' THEN 'Immediate Action Required'
        WHEN health_status = 'WARNING' THEN 'Monitoring Recommended'
        ELSE 'No Action Needed'
    END as priority_level
FROM bot_health_metrics 
WHERE health_status IN ('CRITICAL', 'WARNING')
ORDER BY 
    CASE health_status 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'WARNING' THEN 2 
    END,
    metric_name;

-- Health trend analysis (requires historical data)
SELECT 
    'Bot Health Summary' as summary_type,
    COUNT(*) as total_metrics,
    COUNT(CASE WHEN health_status = 'HEALTHY' THEN 1 END) as healthy_metrics,
    COUNT(CASE WHEN health_status = 'WARNING' THEN 1 END) as warning_metrics,
    COUNT(CASE WHEN health_status = 'CRITICAL' THEN 1 END) as critical_metrics,
    ROUND(COUNT(CASE WHEN health_status = 'HEALTHY' THEN 1 END) * 100.0 / COUNT(*), 1) as health_score_pct
FROM bot_health_metrics;

-- =====================================================
-- 4. ANALYTICS QUERIES: Health Insights
-- =====================================================

-- Performance vs Health correlation
SELECT 
    bh.metric_name,
    bh.metric_value,
    bh.health_status,
    CASE 
        WHEN bh.metric_name = 'overall_win_rate' THEN 
            (SELECT ROUND(AVG(profit_pct), 2) FROM trades WHERE is_open = 0)
        WHEN bh.metric_name = 'average_profit_pct' THEN 
            (SELECT ROUND(COUNT(*), 0) FROM trades WHERE is_open = 0)
        ELSE NULL
    END as correlated_value
FROM bot_health_metrics bh
WHERE bh.metric_name IN ('overall_win_rate', 'average_profit_pct')
ORDER BY bh.metric_name;

-- Risk management health assessment
SELECT 
    'Risk Management Health' as assessment_type,
    (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'worst_loss_control') as worst_loss_pct,
    (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'stop_loss_utilization_rate') as sl_trigger_rate_pct,
    (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'portfolio_diversification') as pairs_traded,
    CASE 
        WHEN (SELECT health_status FROM bot_health_metrics WHERE metric_name = 'worst_loss_control') = 'HEALTHY'
         AND (SELECT health_status FROM bot_health_metrics WHERE metric_name = 'stop_loss_utilization_rate') = 'HEALTHY'
         AND (SELECT health_status FROM bot_health_metrics WHERE metric_name = 'portfolio_diversification') = 'HEALTHY'
        THEN 'EXCELLENT'
        WHEN (SELECT health_status FROM bot_health_metrics WHERE metric_name = 'worst_loss_control') != 'CRITICAL'
         AND (SELECT health_status FROM bot_health_metrics WHERE metric_name = 'stop_loss_utilization_rate') != 'CRITICAL'
        THEN 'ACCEPTABLE'
        ELSE 'NEEDS_IMPROVEMENT'
    END as overall_risk_health;

-- Performance efficiency assessment
SELECT 
    'Performance Efficiency' as assessment_type,
    (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'trade_duration_efficiency') as avg_duration_min,
    (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'trading_activity') as activity_consistency_pct,
    (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'strategy_utilization') as strategies_count,
    CASE 
        WHEN (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'trade_duration_efficiency') <= 240
         AND (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'trading_activity') >= 60
        THEN 'HIGHLY_EFFICIENT'
        WHEN (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'trade_duration_efficiency') <= 480
         AND (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'trading_activity') >= 40
        THEN 'MODERATELY_EFFICIENT'
        ELSE 'LOW_EFFICIENCY'
    END as efficiency_rating;

-- Profitability health check
SELECT 
    'Profitability Health Check' as check_type,
    (SELECT ROUND(metric_value, 2) FROM bot_health_metrics WHERE metric_name = 'total_profit_abs') as total_profit,
    (SELECT ROUND(metric_value, 2) FROM bot_health_metrics WHERE metric_name = 'average_profit_pct') as avg_profit_pct,
    (SELECT ROUND(metric_value, 1) FROM bot_health_metrics WHERE metric_name = 'overall_win_rate') as win_rate_pct,
    (SELECT ROUND(metric_value, 2) FROM bot_health_metrics WHERE metric_name = 'best_win_achievement') as best_win_pct,
    CASE 
        WHEN (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'total_profit_abs') > 0
         AND (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'average_profit_pct') > 0.5
         AND (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'overall_win_rate') > 60
        THEN 'PROFITABLE'
        WHEN (SELECT metric_value FROM bot_health_metrics WHERE metric_name = 'total_profit_abs') >= 0
        THEN 'BREAK_EVEN'
        ELSE 'UNPROFITABLE'
    END as profitability_status;

-- =====================================================
-- 5. ALERT SYSTEM QUERIES
-- =====================================================

-- Critical alerts requiring immediate attention
SELECT 
    metric_name as alert_metric,
    metric_value as current_value,
    threshold_critical as critical_threshold,
    metric_unit,
    recommendation as action_required,
    'CRITICAL ALERT' as alert_level,
    CURRENT_TIMESTAMP as alert_time
FROM bot_health_metrics 
WHERE health_status = 'CRITICAL'
ORDER BY metric_name;

-- Warning alerts for monitoring
SELECT 
    metric_name as alert_metric,
    metric_value as current_value,
    threshold_warning as warning_threshold,
    metric_unit,
    recommendation as suggested_action,
    'WARNING ALERT' as alert_level,
    CURRENT_TIMESTAMP as alert_time
FROM bot_health_metrics 
WHERE health_status = 'WARNING'
ORDER BY metric_name;

-- Health score calculation
SELECT 
    'Overall Bot Health Score' as metric_type,
    ROUND(
        (COUNT(CASE WHEN health_status = 'HEALTHY' THEN 1 END) * 100.0 / COUNT(*)), 1
    ) as health_score_pct,
    COUNT(CASE WHEN health_status = 'HEALTHY' THEN 1 END) as healthy_count,
    COUNT(CASE WHEN health_status = 'WARNING' THEN 1 END) as warning_count,
    COUNT(CASE WHEN health_status = 'CRITICAL' THEN 1 END) as critical_count,
    COUNT(*) as total_metrics,
    CASE 
        WHEN (COUNT(CASE WHEN health_status = 'HEALTHY' THEN 1 END) * 100.0 / COUNT(*)) >= 80 THEN 'EXCELLENT'
        WHEN (COUNT(CASE WHEN health_status = 'HEALTHY' THEN 1 END) * 100.0 / COUNT(*)) >= 70 THEN 'GOOD'
        WHEN (COUNT(CASE WHEN health_status = 'HEALTHY' THEN 1 END) * 100.0 / COUNT(*)) >= 60 THEN 'ACCEPTABLE'
        ELSE 'NEEDS_ATTENTION'
    END as overall_health_rating
FROM bot_health_metrics;

-- =====================================================
-- 6. DIRECT TRADES TABLE HEALTH ANALYSIS
-- =====================================================

-- Real-time health check from trades table
SELECT 
    'Real-time Health Check' as check_type,
    COUNT(*) as total_trades,
    ROUND(AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) * 100, 1) as current_win_rate_pct,
    ROUND(AVG(profit_pct), 2) as current_avg_profit_pct,
    ROUND(SUM(profit_abs), 2) as current_total_profit,
    ROUND(MIN(profit_pct), 2) as current_worst_loss_pct,
    COUNT(DISTINCT pair) as pairs_currently_traded,
    COUNT(DISTINCT strategy) as strategies_currently_used,
    CASE 
        WHEN AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) >= 0.6 
         AND AVG(profit_pct) >= 0.5 
         AND SUM(profit_abs) > 0 
        THEN 'HEALTHY'
        WHEN AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) >= 0.4 
         AND SUM(profit_abs) >= 0 
        THEN 'WARNING'
        ELSE 'CRITICAL'
    END as real_time_health_status
FROM trades 
WHERE is_open = 0;

-- Recent performance trend (last 30 trades)
SELECT 
    'Recent Performance Trend' as trend_type,
    COUNT(*) as recent_trades,
    ROUND(AVG(profit_pct), 2) as recent_avg_profit_pct,
    ROUND(AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) * 100, 1) as recent_win_rate_pct,
    ROUND(SUM(profit_abs), 2) as recent_total_profit,
    ROUND(AVG(trade_duration), 0) as recent_avg_duration_min,
    CASE 
        WHEN AVG(profit_pct) >= 0.5 AND AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) >= 0.6 THEN 'IMPROVING'
        WHEN AVG(profit_pct) >= 0.0 THEN 'STABLE'
        ELSE 'DECLINING'
    END as trend_direction
FROM (
    SELECT profit_pct, trade_duration, profit_abs
    FROM trades 
    WHERE is_open = 0 
    ORDER BY trade_id DESC 
    LIMIT 30
) recent_trades;

-- System utilization metrics
SELECT 
    'System Utilization' as metric_type,
    COUNT(DISTINCT pair) as unique_pairs_traded,
    COUNT(DISTINCT strategy) as unique_strategies_used,
    COUNT(DISTINCT base_currency) as unique_base_currencies,
    COUNT(DISTINCT quote_currency) as unique_quote_currencies,
    COUNT(DISTINCT DATE(open_date)) as unique_trading_days,
    ROUND(AVG(stake_amount), 2) as avg_stake_per_trade,
    ROUND(SUM(stake_amount), 2) as total_capital_deployed,
    CASE 
        WHEN COUNT(DISTINCT pair) >= 5 AND COUNT(DISTINCT strategy) >= 2 THEN 'WELL_DIVERSIFIED'
        WHEN COUNT(DISTINCT pair) >= 3 THEN 'MODERATELY_DIVERSIFIED'
        ELSE 'LOW_DIVERSIFICATION'
    END as diversification_level
FROM trades 
WHERE is_open = 0;

-- =====================================================
-- 7. MAINTENANCE QUERIES
-- =====================================================

-- Recalculate all bot health metrics
DELETE FROM bot_health_metrics;

-- Re-run INSERT statement from section 2
-- ... (Would typically be executed by automation system)

-- Data quality check for bot health metrics
SELECT 
    'Bot Health Metrics Quality Check' as check_type,
    COUNT(*) as total_metrics,
    COUNT(CASE WHEN metric_value IS NULL THEN 1 END) as null_value_count,
    COUNT(CASE WHEN health_status IS NULL THEN 1 END) as null_status_count,
    COUNT(CASE WHEN health_status NOT IN ('HEALTHY', 'WARNING', 'CRITICAL') THEN 1 END) as invalid_status_count,
    COUNT(CASE WHEN metric_unit IS NULL THEN 1 END) as null_unit_count
FROM bot_health_metrics;

-- Health metrics history (for trending - requires historical snapshots)
SELECT 
    metric_name,
    metric_value,
    health_status,
    analysis_date,
    LAG(metric_value) OVER (PARTITION BY metric_name ORDER BY analysis_date) as previous_value,
    ROUND(metric_value - LAG(metric_value) OVER (PARTITION BY metric_name ORDER BY analysis_date), 2) as value_change
FROM bot_health_metrics 
ORDER BY metric_name, analysis_date DESC;