-- Stop Loss Analytics SQL
-- Purpose: Analyzes stop loss effectiveness and optimization
-- Data Source: ~/db_dev/trading_test.db trades table
-- Key Metrics: Trigger rates, effectiveness percentages, optimal levels

-- =====================================================
-- 1. CREATE TABLE: stop_loss_analytics
-- =====================================================

CREATE TABLE IF NOT EXISTS stop_loss_analytics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_type TEXT NOT NULL,            -- 'overall', 'by_pair', 'by_strategy'
    pair TEXT,                              -- Trading pair (NULL for overall)
    strategy TEXT,                          -- Strategy name (NULL for pair/overall)
    stop_loss_level_pct REAL,              -- Average stop loss level percentage
    total_trades_with_sl INTEGER,          -- Total trades with stop loss set
    sl_triggered_count INTEGER,            -- Number of times stop loss was triggered
    sl_trigger_rate_pct REAL,              -- Stop loss trigger rate percentage
    sl_effectiveness_pct REAL,             -- How effective stop losses are at limiting losses
    avg_loss_when_triggered_pct REAL,      -- Average loss when stop loss triggers
    avg_profit_when_not_triggered_pct REAL, -- Average profit when stop loss doesn't trigger
    max_loss_prevented_pct REAL,           -- Maximum loss that was prevented
    optimal_sl_level_pct REAL,             -- Calculated optimal stop loss level
    trades_without_sl INTEGER,             -- Trades without stop loss protection
    avg_loss_without_sl_pct REAL,          -- Average loss on trades without stop loss
    analysis_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for performance
    UNIQUE(analysis_type, pair, strategy)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_stop_loss_analytics_type ON stop_loss_analytics(analysis_type);
CREATE INDEX IF NOT EXISTS idx_stop_loss_analytics_pair ON stop_loss_analytics(pair);
CREATE INDEX IF NOT EXISTS idx_stop_loss_analytics_effectiveness ON stop_loss_analytics(sl_effectiveness_pct DESC);

-- =====================================================
-- 2. POPULATE TABLE: Overall Stop Loss Analytics
-- =====================================================

-- Clear existing overall analytics
DELETE FROM stop_loss_analytics WHERE analysis_type = 'overall';

-- Insert overall stop loss analytics
-- Based on actual implementation from trading_analytics_automation_final.py
INSERT INTO stop_loss_analytics (
    analysis_type, stop_loss_level_pct, total_trades_with_sl,
    sl_triggered_count, sl_trigger_rate_pct, sl_effectiveness_pct, 
    avg_loss_when_triggered_pct, avg_profit_when_not_triggered_pct,
    trades_without_sl, avg_loss_without_sl_pct, analysis_date
)
SELECT 
    'overall' as analysis_type,
    AVG(stop_loss_pct) as stop_loss_level_pct,
    COUNT(*) as total_trades_with_sl,
    SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as sl_triggered_count,
    ROUND(SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as sl_trigger_rate_pct,
    CASE 
        WHEN SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) > 0
        THEN ROUND((SUM(CASE WHEN exit_reason = 'stop_loss' AND profit_pct > -10 THEN 1 ELSE 0 END) * 100.0 / 
              SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END)), 2)
        ELSE 0
    END as sl_effectiveness_pct,
    AVG(CASE WHEN exit_reason = 'stop_loss' THEN profit_pct ELSE NULL END) as avg_loss_when_triggered_pct,
    AVG(CASE WHEN exit_reason != 'stop_loss' THEN profit_pct ELSE NULL END) as avg_profit_when_not_triggered_pct,
    (SELECT COUNT(*) FROM trades WHERE is_open = 0 AND stop_loss_pct IS NULL) as trades_without_sl,
    (SELECT AVG(CASE WHEN profit_pct < 0 THEN profit_pct ELSE NULL END) 
     FROM trades WHERE is_open = 0 AND stop_loss_pct IS NULL) as avg_loss_without_sl_pct,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0 AND stop_loss_pct IS NOT NULL;

-- =====================================================
-- 3. POPULATE TABLE: Stop Loss Analytics by Pair
-- =====================================================

-- Clear existing pair-level analytics
DELETE FROM stop_loss_analytics WHERE analysis_type = 'by_pair';

-- Insert stop loss analytics for each trading pair
INSERT INTO stop_loss_analytics (
    analysis_type, pair, stop_loss_level_pct, total_trades_with_sl,
    sl_triggered_count, sl_trigger_rate_pct, sl_effectiveness_pct,
    avg_loss_when_triggered_pct, avg_profit_when_not_triggered_pct,
    analysis_date
)
SELECT 
    'by_pair' as analysis_type,
    pair,
    AVG(stop_loss_pct) as stop_loss_level_pct,
    COUNT(*) as total_trades_with_sl,
    SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as sl_triggered_count,
    ROUND(SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as sl_trigger_rate_pct,
    CASE 
        WHEN SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) > 0
        THEN ROUND((SUM(CASE WHEN exit_reason = 'stop_loss' AND profit_pct > -10 THEN 1 ELSE 0 END) * 100.0 / 
              SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END)), 2)
        ELSE 0
    END as sl_effectiveness_pct,
    AVG(CASE WHEN exit_reason = 'stop_loss' THEN profit_pct ELSE NULL END) as avg_loss_when_triggered_pct,
    AVG(CASE WHEN exit_reason != 'stop_loss' THEN profit_pct ELSE NULL END) as avg_profit_when_not_triggered_pct,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0 AND stop_loss_pct IS NOT NULL
GROUP BY pair
HAVING COUNT(*) >= 3;  -- Only pairs with meaningful sample size

-- =====================================================
-- 4. POPULATE TABLE: Stop Loss Analytics by Strategy
-- =====================================================

-- Clear existing strategy-level analytics
DELETE FROM stop_loss_analytics WHERE analysis_type = 'by_strategy';

-- Insert stop loss analytics for each strategy
INSERT INTO stop_loss_analytics (
    analysis_type, strategy, stop_loss_level_pct, total_trades_with_sl,
    sl_triggered_count, sl_trigger_rate_pct, sl_effectiveness_pct,
    avg_loss_when_triggered_pct, avg_profit_when_not_triggered_pct,
    analysis_date
)
SELECT 
    'by_strategy' as analysis_type,
    strategy,
    AVG(stop_loss_pct) as stop_loss_level_pct,
    COUNT(*) as total_trades_with_sl,
    SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as sl_triggered_count,
    ROUND(SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as sl_trigger_rate_pct,
    CASE 
        WHEN SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) > 0
        THEN ROUND((SUM(CASE WHEN exit_reason = 'stop_loss' AND profit_pct > -5 THEN 1 ELSE 0 END) * 100.0 / 
              SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END)), 2)
        ELSE 0
    END as sl_effectiveness_pct,
    AVG(CASE WHEN exit_reason = 'stop_loss' THEN profit_pct ELSE NULL END) as avg_loss_when_triggered_pct,
    AVG(CASE WHEN exit_reason != 'stop_loss' THEN profit_pct ELSE NULL END) as avg_profit_when_not_triggered_pct,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0 AND stop_loss_pct IS NOT NULL
GROUP BY strategy
HAVING COUNT(*) >= 5;  -- Only strategies with meaningful sample size

-- =====================================================
-- 5. ADVANCED STOP LOSS CALCULATIONS
-- =====================================================

-- Calculate optimal stop loss levels for each pair
UPDATE stop_loss_analytics SET
    optimal_sl_level_pct = (
        -- Find the stop loss level that maximizes (prevented_losses - missed_profits)
        SELECT stop_loss_level
        FROM (
            SELECT 
                ROUND(stop_loss_pct, 1) as stop_loss_level,
                COUNT(*) as trades_at_level,
                AVG(profit_pct) as avg_outcome,
                SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as triggered_count
            FROM trades 
            WHERE is_open = 0 
              AND stop_loss_pct IS NOT NULL 
              AND (pair = stop_loss_analytics.pair OR stop_loss_analytics.pair IS NULL)
            GROUP BY ROUND(stop_loss_pct, 1)
            HAVING trades_at_level >= 2
            ORDER BY avg_outcome DESC
            LIMIT 1
        ) optimal_levels
    )
WHERE analysis_type IN ('by_pair', 'overall');

-- Calculate maximum loss prevented by stop losses
UPDATE stop_loss_analytics SET
    max_loss_prevented_pct = (
        SELECT ABS(MIN(profit_pct))
        FROM trades 
        WHERE is_open = 0 
          AND exit_reason = 'stop_loss'
          AND (pair = stop_loss_analytics.pair OR stop_loss_analytics.pair IS NULL)
          AND (strategy = stop_loss_analytics.strategy OR stop_loss_analytics.strategy IS NULL)
    );

-- =====================================================
-- 6. QUERY EXAMPLES: Stop Loss Analytics
-- =====================================================

-- Overall stop loss summary
SELECT 
    analysis_type,
    ROUND(stop_loss_level_pct, 2) as avg_sl_level_pct,
    total_trades_with_sl,
    sl_triggered_count,
    sl_trigger_rate_pct,
    sl_effectiveness_pct,
    ROUND(avg_loss_when_triggered_pct, 2) as avg_loss_when_triggered_pct,
    ROUND(avg_profit_when_not_triggered_pct, 2) as avg_profit_when_not_triggered_pct,
    trades_without_sl
FROM stop_loss_analytics 
WHERE analysis_type = 'overall';

-- Stop loss effectiveness by pair
SELECT 
    pair,
    total_trades_with_sl,
    sl_triggered_count,
    sl_trigger_rate_pct,
    sl_effectiveness_pct,
    ROUND(stop_loss_level_pct, 2) as avg_sl_level_pct,
    ROUND(optimal_sl_level_pct, 2) as optimal_sl_level_pct,
    ROUND(avg_loss_when_triggered_pct, 2) as avg_loss_triggered,
    ROUND(avg_profit_when_not_triggered_pct, 2) as avg_profit_not_triggered
FROM stop_loss_analytics 
WHERE analysis_type = 'by_pair'
ORDER BY sl_effectiveness_pct DESC;

-- Stop loss effectiveness by strategy
SELECT 
    strategy,
    total_trades_with_sl,
    sl_triggered_count,
    sl_trigger_rate_pct,
    sl_effectiveness_pct,
    ROUND(stop_loss_level_pct, 2) as avg_sl_level_pct,
    ROUND(avg_loss_when_triggered_pct, 2) as avg_loss_triggered,
    ROUND(max_loss_prevented_pct, 2) as max_loss_prevented
FROM stop_loss_analytics 
WHERE analysis_type = 'by_strategy'
ORDER BY sl_effectiveness_pct DESC;

-- Pairs needing stop loss optimization
SELECT 
    pair,
    sl_effectiveness_pct,
    sl_trigger_rate_pct,
    ROUND(stop_loss_level_pct, 2) as current_avg_sl,
    ROUND(optimal_sl_level_pct, 2) as suggested_sl,
    CASE 
        WHEN sl_effectiveness_pct < 50 THEN 'Needs Improvement'
        WHEN sl_trigger_rate_pct > 30 THEN 'Too Aggressive'
        WHEN sl_trigger_rate_pct < 5 THEN 'Too Loose'
        ELSE 'Acceptable'
    END as sl_assessment
FROM stop_loss_analytics 
WHERE analysis_type = 'by_pair'
ORDER BY sl_effectiveness_pct ASC;

-- =====================================================
-- 7. ANALYTICS QUERIES: Stop Loss Insights
-- =====================================================

-- Stop loss effectiveness distribution
SELECT 
    CASE 
        WHEN sl_effectiveness_pct >= 80 THEN 'Excellent (≥80%)'
        WHEN sl_effectiveness_pct >= 60 THEN 'Good (60-80%)'
        WHEN sl_effectiveness_pct >= 40 THEN 'Average (40-60%)'
        WHEN sl_effectiveness_pct > 0 THEN 'Poor (<40%)'
        ELSE 'No Stop-Loss Triggers'
    END as effectiveness_category,
    COUNT(*) as pair_count,
    ROUND(AVG(sl_effectiveness_pct), 1) as avg_effectiveness,
    ROUND(AVG(sl_trigger_rate_pct), 1) as avg_trigger_rate,
    ROUND(AVG(stop_loss_level_pct), 2) as avg_sl_level
FROM stop_loss_analytics 
WHERE analysis_type = 'by_pair'
GROUP BY 
    CASE 
        WHEN sl_effectiveness_pct >= 80 THEN 'Excellent (≥80%)'
        WHEN sl_effectiveness_pct >= 60 THEN 'Good (60-80%)'
        WHEN sl_effectiveness_pct >= 40 THEN 'Average (40-60%)'
        WHEN sl_effectiveness_pct > 0 THEN 'Poor (<40%)'
        ELSE 'No Stop-Loss Triggers'
    END
ORDER BY avg_effectiveness DESC;

-- Stop loss trigger rate analysis
SELECT 
    CASE 
        WHEN sl_trigger_rate_pct >= 30 THEN 'High Trigger Rate (≥30%)'
        WHEN sl_trigger_rate_pct >= 15 THEN 'Medium Trigger Rate (15-30%)'
        WHEN sl_trigger_rate_pct >= 5 THEN 'Low Trigger Rate (5-15%)'
        ELSE 'Very Low Trigger Rate (<5%)'
    END as trigger_rate_category,
    COUNT(*) as pair_count,
    ROUND(AVG(sl_trigger_rate_pct), 1) as avg_trigger_rate,
    ROUND(AVG(sl_effectiveness_pct), 1) as avg_effectiveness,
    ROUND(AVG(avg_loss_when_triggered_pct), 2) as avg_loss_when_triggered
FROM stop_loss_analytics 
WHERE analysis_type = 'by_pair'
GROUP BY 
    CASE 
        WHEN sl_trigger_rate_pct >= 30 THEN 'High Trigger Rate (≥30%)'
        WHEN sl_trigger_rate_pct >= 15 THEN 'Medium Trigger Rate (15-30%)'
        WHEN sl_trigger_rate_pct >= 5 THEN 'Low Trigger Rate (5-15%)'
        ELSE 'Very Low Trigger Rate (<5%)'
    END
ORDER BY avg_trigger_rate DESC;

-- Stop loss level optimization analysis
SELECT 
    CASE 
        WHEN stop_loss_level_pct <= -10 THEN 'Very Tight (≤-10%)'
        WHEN stop_loss_level_pct <= -5 THEN 'Tight (-5% to -10%)'
        WHEN stop_loss_level_pct <= -2 THEN 'Moderate (-2% to -5%)'
        ELSE 'Loose (>-2%)'
    END as sl_level_category,
    COUNT(*) as pair_count,
    ROUND(AVG(stop_loss_level_pct), 2) as avg_sl_level,
    ROUND(AVG(sl_trigger_rate_pct), 1) as avg_trigger_rate,
    ROUND(AVG(sl_effectiveness_pct), 1) as avg_effectiveness,
    ROUND(AVG(avg_profit_when_not_triggered_pct), 2) as avg_profit_no_trigger
FROM stop_loss_analytics 
WHERE analysis_type = 'by_pair' AND stop_loss_level_pct IS NOT NULL
GROUP BY 
    CASE 
        WHEN stop_loss_level_pct <= -10 THEN 'Very Tight (≤-10%)'
        WHEN stop_loss_level_pct <= -5 THEN 'Tight (-5% to -10%)'
        WHEN stop_loss_level_pct <= -2 THEN 'Moderate (-2% to -5%)'
        ELSE 'Loose (>-2%)'
    END
ORDER BY avg_effectiveness DESC;

-- =====================================================
-- 8. DIRECT TRADES TABLE STOP LOSS ANALYSIS
-- =====================================================

-- Quick stop loss analysis directly from trades table
SELECT 
    'Stop Loss Overview' as analysis_type,
    COUNT(*) as total_trades,
    SUM(CASE WHEN stop_loss_pct IS NOT NULL THEN 1 ELSE 0 END) as trades_with_sl,
    ROUND(SUM(CASE WHEN stop_loss_pct IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as sl_usage_rate_pct,
    SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as sl_triggered,
    ROUND(SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(SUM(CASE WHEN stop_loss_pct IS NOT NULL THEN 1 ELSE 0 END), 0), 1) as sl_trigger_rate_pct,
    ROUND(AVG(CASE WHEN stop_loss_pct IS NOT NULL THEN stop_loss_pct END), 2) as avg_sl_level_pct,
    ROUND(AVG(CASE WHEN exit_reason = 'stop_loss' THEN profit_pct END), 2) as avg_loss_when_triggered
FROM trades 
WHERE is_open = 0;

-- Stop loss performance by exit reason
SELECT 
    exit_reason,
    COUNT(*) as trade_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM trades WHERE is_open = 0), 1) as percentage_of_trades,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(MIN(profit_pct), 2) as worst_outcome_pct,
    ROUND(MAX(profit_pct), 2) as best_outcome_pct,
    ROUND(AVG(trade_duration), 0) as avg_duration_min
FROM trades 
WHERE is_open = 0 
  AND exit_reason IS NOT NULL
GROUP BY exit_reason
ORDER BY trade_count DESC;

-- Comparison: trades with vs without stop loss
SELECT 
    'With Stop Loss' as protection_type,
    COUNT(*) as trade_count,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(MIN(profit_pct), 2) as worst_loss_pct,
    ROUND(AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) * 100, 1) as win_rate_pct,
    SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as protection_triggered
FROM trades 
WHERE is_open = 0 AND stop_loss_pct IS NOT NULL

UNION ALL

SELECT 
    'Without Stop Loss' as protection_type,
    COUNT(*) as trade_count,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(MIN(profit_pct), 2) as worst_loss_pct,
    ROUND(AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) * 100, 1) as win_rate_pct,
    0 as protection_triggered
FROM trades 
WHERE is_open = 0 AND stop_loss_pct IS NULL

ORDER BY protection_type;

-- Stop loss level distribution
SELECT 
    CASE 
        WHEN stop_loss_pct <= -15 THEN 'Very Tight (≤-15%)'
        WHEN stop_loss_pct <= -10 THEN 'Tight (-10% to -15%)'
        WHEN stop_loss_pct <= -5 THEN 'Moderate (-5% to -10%)'
        WHEN stop_loss_pct <= -2 THEN 'Loose (-2% to -5%)'
        ELSE 'Very Loose (>-2%)'
    END as sl_level_range,
    COUNT(*) as trade_count,
    ROUND(AVG(stop_loss_pct), 2) as avg_sl_level,
    SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as triggered_count,
    ROUND(SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as trigger_rate_pct,
    ROUND(AVG(profit_pct), 2) as avg_outcome_pct
FROM trades 
WHERE is_open = 0 AND stop_loss_pct IS NOT NULL
GROUP BY 
    CASE 
        WHEN stop_loss_pct <= -15 THEN 'Very Tight (≤-15%)'
        WHEN stop_loss_pct <= -10 THEN 'Tight (-10% to -15%)'
        WHEN stop_loss_pct <= -5 THEN 'Moderate (-5% to -10%)'
        WHEN stop_loss_pct <= -2 THEN 'Loose (-2% to -5%)'
        ELSE 'Very Loose (>-2%)'
    END
ORDER BY avg_sl_level;

-- =====================================================
-- 9. MAINTENANCE QUERIES
-- =====================================================

-- Recalculate all stop loss analytics
DELETE FROM stop_loss_analytics;

-- Re-run INSERT statements from sections 2, 3, and 4
-- ... (Would typically be executed by automation system)

-- Data quality check for stop loss analytics
SELECT 
    'Stop Loss Analytics Quality Check' as check_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN sl_effectiveness_pct IS NULL THEN 1 END) as null_effectiveness_count,
    COUNT(CASE WHEN sl_trigger_rate_pct IS NULL THEN 1 END) as null_trigger_rate_count,
    COUNT(CASE WHEN sl_effectiveness_pct > 100 THEN 1 END) as invalid_effectiveness_count,
    COUNT(CASE WHEN total_trades_with_sl < sl_triggered_count THEN 1 END) as logic_errors
FROM stop_loss_analytics;