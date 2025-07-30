-- Risk Metrics SQL
-- Purpose: Tracks risk management effectiveness
-- Data Source: ~/db_dev/trading_test.db trades table
-- Key Metrics: Stop-loss triggers, effectiveness percentages, drawdown

-- =====================================================
-- 1. CREATE TABLE: risk_metrics
-- =====================================================

CREATE TABLE IF NOT EXISTS risk_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_type TEXT NOT NULL,               -- 'overall', 'by_pair', 'by_strategy'
    stop_loss_triggered_count INTEGER,      -- Number of stop-loss triggered trades
    stop_loss_effectiveness_pct REAL,       -- How effective stop-losses are
    sharpe_ratio REAL,                      -- Risk-adjusted return metric
    max_drawdown_pct REAL,                  -- Maximum drawdown percentage
    volatility_pct REAL,                    -- Portfolio volatility
    var_95_pct REAL,                        -- Value at Risk (95% confidence)
    risk_reward_ratio REAL,                 -- Average risk vs reward
    analysis_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Optional grouping fields
    entity_name TEXT,                       -- Pair/strategy name (for grouped metrics)
    
    -- Indexes for performance
    UNIQUE(metric_type, entity_name)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_risk_metrics_type ON risk_metrics(metric_type);
CREATE INDEX IF NOT EXISTS idx_risk_metrics_date ON risk_metrics(analysis_date);

-- =====================================================
-- 2. POPULATE TABLE: Overall Risk Metrics
-- =====================================================

-- Clear existing overall metrics and recalculate
DELETE FROM risk_metrics WHERE metric_type = 'overall';

-- Insert overall risk management metrics
-- Based on actual implementation from trading_analytics_automation_final.py
INSERT INTO risk_metrics (
    metric_type, stop_loss_triggered_count, 
    stop_loss_effectiveness_pct, sharpe_ratio,
    max_drawdown_pct, analysis_date
)
SELECT 
    'overall' as metric_type,
    SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as sl_triggered,
    CASE 
        WHEN SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) > 0 
        THEN (SUM(CASE WHEN exit_reason = 'stop_loss' AND profit_abs < 0 THEN ABS(profit_abs) ELSE 0 END) / 
              NULLIF(SUM(CASE WHEN profit_abs < 0 THEN ABS(profit_abs) ELSE 0 END), 0) * 100)
        ELSE 0 
    END as sl_effectiveness,
    0.0 as sharpe_ratio,  -- Simplified for now
    MIN(profit_pct) as max_drawdown_pct,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0;

-- =====================================================
-- 3. POPULATE TABLE: Risk Metrics by Pair
-- =====================================================

-- Clear existing pair-level metrics
DELETE FROM risk_metrics WHERE metric_type = 'by_pair';

-- Insert risk metrics for each trading pair
INSERT INTO risk_metrics (
    metric_type, entity_name, stop_loss_triggered_count,
    stop_loss_effectiveness_pct, max_drawdown_pct, 
    volatility_pct, risk_reward_ratio, analysis_date
)
SELECT 
    'by_pair' as metric_type,
    pair as entity_name,
    SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as sl_triggered,
    CASE 
        WHEN SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) > 0
        THEN (SUM(CASE WHEN exit_reason = 'stop_loss' AND profit_pct > -10 THEN 1 ELSE 0 END) * 100.0 / 
              SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END))
        ELSE 0
    END as sl_effectiveness_pct,
    MIN(profit_pct) as max_drawdown_pct,
    CASE 
        WHEN COUNT(*) > 1 
        THEN SQRT(AVG(profit_pct * profit_pct) - AVG(profit_pct) * AVG(profit_pct))
        ELSE 0 
    END as volatility_pct,
    CASE 
        WHEN AVG(CASE WHEN profit_pct < 0 THEN ABS(profit_pct) ELSE 0 END) > 0
        THEN AVG(CASE WHEN profit_pct > 0 THEN profit_pct ELSE 0 END) / 
             AVG(CASE WHEN profit_pct < 0 THEN ABS(profit_pct) ELSE 0 END)
        ELSE 0
    END as risk_reward_ratio,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0
GROUP BY pair
HAVING COUNT(*) >= 3;  -- Only pairs with meaningful sample size

-- =====================================================
-- 4. POPULATE TABLE: Risk Metrics by Strategy
-- =====================================================

-- Clear existing strategy-level metrics
DELETE FROM risk_metrics WHERE metric_type = 'by_strategy';

-- Insert risk metrics for each strategy
INSERT INTO risk_metrics (
    metric_type, entity_name, stop_loss_triggered_count,
    stop_loss_effectiveness_pct, max_drawdown_pct,
    volatility_pct, risk_reward_ratio, analysis_date
)
SELECT 
    'by_strategy' as metric_type,
    strategy as entity_name,
    SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as sl_triggered,
    CASE 
        WHEN SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) > 0
        THEN (SUM(CASE WHEN exit_reason = 'stop_loss' AND profit_pct > -5 THEN 1 ELSE 0 END) * 100.0 / 
              SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END))
        ELSE 0
    END as sl_effectiveness_pct,
    MIN(profit_pct) as max_drawdown_pct,
    CASE 
        WHEN COUNT(*) > 1 
        THEN SQRT(AVG(profit_pct * profit_pct) - AVG(profit_pct) * AVG(profit_pct))
        ELSE 0 
    END as volatility_pct,
    CASE 
        WHEN AVG(CASE WHEN profit_pct < 0 THEN ABS(profit_pct) ELSE 0 END) > 0
        THEN AVG(CASE WHEN profit_pct > 0 THEN profit_pct ELSE 0 END) / 
             AVG(CASE WHEN profit_pct < 0 THEN ABS(profit_pct) ELSE 0 END)
        ELSE 0
    END as risk_reward_ratio,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0
GROUP BY strategy
HAVING COUNT(*) >= 5;  -- Only strategies with meaningful sample size

-- =====================================================
-- 5. ADVANCED RISK CALCULATIONS
-- =====================================================

-- Value at Risk (VaR) calculation - 95th percentile of losses
INSERT OR REPLACE INTO risk_metrics (
    metric_type, entity_name, var_95_pct, analysis_date
)
SELECT 
    'var_analysis' as metric_type,
    'portfolio' as entity_name,
    (SELECT profit_pct 
     FROM trades 
     WHERE is_open = 0 AND profit_pct < 0
     ORDER BY profit_pct ASC 
     LIMIT 1 OFFSET (SELECT CAST(COUNT(*) * 0.05 AS INTEGER) 
                     FROM trades 
                     WHERE is_open = 0 AND profit_pct < 0)
    ) as var_95_pct,
    CURRENT_TIMESTAMP as analysis_date;

-- =====================================================
-- 6. QUERY EXAMPLES: Risk Metrics Analysis
-- =====================================================

-- Overall portfolio risk summary
SELECT 
    metric_type,
    stop_loss_triggered_count,
    ROUND(stop_loss_effectiveness_pct, 2) as sl_effectiveness_pct,
    ROUND(max_drawdown_pct, 2) as max_drawdown_pct,
    ROUND(sharpe_ratio, 3) as sharpe_ratio
FROM risk_metrics 
WHERE metric_type = 'overall';

-- Stop-loss effectiveness by pair
SELECT 
    entity_name as trading_pair,
    stop_loss_triggered_count as sl_triggers,
    ROUND(stop_loss_effectiveness_pct, 1) as sl_effectiveness_pct,
    ROUND(max_drawdown_pct, 2) as max_drawdown_pct,
    ROUND(volatility_pct, 2) as volatility_pct,
    ROUND(risk_reward_ratio, 2) as risk_reward_ratio
FROM risk_metrics 
WHERE metric_type = 'by_pair'
ORDER BY sl_effectiveness_pct DESC;

-- Strategy risk comparison
SELECT 
    entity_name as strategy,
    stop_loss_triggered_count as sl_triggers,
    ROUND(stop_loss_effectiveness_pct, 1) as sl_effectiveness_pct,
    ROUND(max_drawdown_pct, 2) as worst_loss_pct,
    ROUND(volatility_pct, 2) as volatility_pct,
    ROUND(risk_reward_ratio, 2) as risk_reward_ratio
FROM risk_metrics 
WHERE metric_type = 'by_strategy'
ORDER BY risk_reward_ratio DESC;

-- High-risk pairs (need attention)
SELECT 
    entity_name as trading_pair,
    ROUND(max_drawdown_pct, 2) as worst_loss_pct,
    ROUND(volatility_pct, 2) as volatility_pct,
    stop_loss_triggered_count as sl_triggers,
    ROUND(stop_loss_effectiveness_pct, 1) as sl_effectiveness_pct
FROM risk_metrics 
WHERE metric_type = 'by_pair'
  AND (max_drawdown_pct < -10 OR volatility_pct > 5 OR stop_loss_effectiveness_pct < 50)
ORDER BY max_drawdown_pct ASC;

-- =====================================================
-- 7. ANALYTICS QUERIES: Risk Insights
-- =====================================================

-- Risk-adjusted performance ranking
SELECT 
    rm.entity_name as trading_pair,
    pr.profit_pct as avg_profit_pct,
    rm.volatility_pct,
    rm.max_drawdown_pct,
    rm.risk_reward_ratio,
    CASE 
        WHEN rm.volatility_pct > 0 
        THEN ROUND(pr.profit_pct / rm.volatility_pct, 2)
        ELSE 0 
    END as risk_adjusted_return
FROM risk_metrics rm
JOIN performance_rankings pr ON rm.entity_name = pr.entity_name 
WHERE rm.metric_type = 'by_pair' 
  AND pr.ranking_type = 'by_pair'
ORDER BY risk_adjusted_return DESC;

-- Stop-loss effectiveness analysis
SELECT 
    CASE 
        WHEN stop_loss_effectiveness_pct >= 80 THEN 'Excellent (≥80%)'
        WHEN stop_loss_effectiveness_pct >= 60 THEN 'Good (60-80%)'
        WHEN stop_loss_effectiveness_pct >= 40 THEN 'Average (40-60%)'
        WHEN stop_loss_effectiveness_pct > 0 THEN 'Poor (<40%)'
        ELSE 'No Stop-Losses'
    END as sl_effectiveness_category,
    COUNT(*) as pair_count,
    ROUND(AVG(stop_loss_effectiveness_pct), 1) as avg_effectiveness,
    ROUND(AVG(max_drawdown_pct), 2) as avg_max_drawdown
FROM risk_metrics 
WHERE metric_type = 'by_pair'
GROUP BY 
    CASE 
        WHEN stop_loss_effectiveness_pct >= 80 THEN 'Excellent (≥80%)'
        WHEN stop_loss_effectiveness_pct >= 60 THEN 'Good (60-80%)'
        WHEN stop_loss_effectiveness_pct >= 40 THEN 'Average (40-60%)'
        WHEN stop_loss_effectiveness_pct > 0 THEN 'Poor (<40%)'
        ELSE 'No Stop-Losses'
    END
ORDER BY avg_effectiveness DESC;

-- Volatility vs Performance correlation
SELECT 
    CASE 
        WHEN rm.volatility_pct >= 5 THEN 'High Volatility (≥5%)'
        WHEN rm.volatility_pct >= 3 THEN 'Medium Volatility (3-5%)'
        WHEN rm.volatility_pct >= 1 THEN 'Low Volatility (1-3%)'
        ELSE 'Very Low Volatility (<1%)'
    END as volatility_category,
    COUNT(*) as pair_count,
    ROUND(AVG(pr.profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(rm.volatility_pct), 2) as avg_volatility,
    ROUND(AVG(rm.risk_reward_ratio), 2) as avg_risk_reward
FROM risk_metrics rm
JOIN performance_rankings pr ON rm.entity_name = pr.entity_name
WHERE rm.metric_type = 'by_pair' AND pr.ranking_type = 'by_pair'
GROUP BY 
    CASE 
        WHEN rm.volatility_pct >= 5 THEN 'High Volatility (≥5%)'
        WHEN rm.volatility_pct >= 3 THEN 'Medium Volatility (3-5%)'  
        WHEN rm.volatility_pct >= 1 THEN 'Low Volatility (1-3%)'
        ELSE 'Very Low Volatility (<1%)'
    END
ORDER BY avg_profit_pct DESC;

-- =====================================================
-- 8. DIRECT TRADES TABLE RISK ANALYSIS
-- =====================================================

-- Quick risk analysis directly from trades table
SELECT 
    'Portfolio Risk Summary' as analysis_type,
    COUNT(*) as total_trades,
    SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as stop_loss_exits,
    ROUND(SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as sl_trigger_rate_pct,
    ROUND(MIN(profit_pct), 2) as worst_trade_pct,
    ROUND(MAX(profit_pct), 2) as best_trade_pct,
    ROUND(SQRT(AVG(profit_pct * profit_pct) - AVG(profit_pct) * AVG(profit_pct)), 2) as volatility_pct,
    ROUND(AVG(CASE WHEN profit_pct > 0 THEN profit_pct ELSE 0 END), 2) as avg_win_pct,
    ROUND(AVG(CASE WHEN profit_pct < 0 THEN ABS(profit_pct) ELSE 0 END), 2) as avg_loss_pct
FROM trades 
WHERE is_open = 0;

-- Risk by exit reason
SELECT 
    exit_reason,
    COUNT(*) as trade_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM trades WHERE is_open = 0), 1) as percentage_of_trades,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(MIN(profit_pct), 2) as worst_case_pct,
    ROUND(MAX(profit_pct), 2) as best_case_pct
FROM trades 
WHERE is_open = 0 
  AND exit_reason IS NOT NULL
GROUP BY exit_reason
ORDER BY trade_count DESC;

-- Drawdown analysis by time periods
SELECT 
    DATE(open_date) as trade_date,
    COUNT(*) as trades_that_day,
    ROUND(AVG(profit_pct), 2) as daily_avg_profit,
    ROUND(MIN(profit_pct), 2) as daily_worst_trade,
    SUM(CASE WHEN profit_pct < 0 THEN 1 ELSE 0 END) as losing_trades
FROM trades 
WHERE is_open = 0 
  AND open_date IS NOT NULL
GROUP BY DATE(open_date)
HAVING trades_that_day >= 2
ORDER BY trade_date DESC
LIMIT 30;

-- =====================================================
-- 9. MAINTENANCE QUERIES
-- =====================================================

-- Recalculate all risk metrics (full refresh)
DELETE FROM risk_metrics;

-- Re-run all INSERT statements from sections 2, 3, and 4
-- ... (Would typically be executed by automation system)

-- Data quality check for risk metrics
SELECT 
    'Risk Metrics Quality Check' as check_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN stop_loss_triggered_count IS NULL THEN 1 END) as null_sl_count,
    COUNT(CASE WHEN max_drawdown_pct IS NULL THEN 1 END) as null_drawdown_count,
    COUNT(CASE WHEN max_drawdown_pct > 0 THEN 1 END) as positive_drawdown_errors
FROM risk_metrics;