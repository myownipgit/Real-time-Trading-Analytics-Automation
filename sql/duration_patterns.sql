-- Duration Patterns SQL
-- Purpose: Analyzes trade duration patterns and optimal exit timing
-- Data Source: ~/db_dev/trading_test.db trades table
-- Key Metrics: Duration categories, optimal timing, exit patterns

-- =====================================================
-- 1. CREATE TABLE: duration_patterns
-- =====================================================

CREATE TABLE IF NOT EXISTS duration_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern_type TEXT NOT NULL,             -- 'duration_based', 'by_pair', 'by_strategy'
    duration_category TEXT,                 -- 'scalp', 'short_term', 'day_trade', 'swing_trade'
    min_duration_minutes REAL,              -- Minimum duration in this category
    max_duration_minutes REAL,              -- Maximum duration in this category
    trade_count INTEGER,                    -- Number of trades in this duration range
    win_rate REAL,                         -- Win rate for this duration category
    avg_profit_pct REAL,                   -- Average profit percentage
    total_profit_abs REAL,                 -- Total absolute profit
    optimal_exit_timing_minutes REAL,      -- Optimal exit timing based on analysis
    profit_per_hour REAL,                  -- Profit per hour for efficiency analysis
    analysis_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Optional grouping fields
    pair TEXT,                             -- Trading pair (for pair-specific analysis)
    strategy TEXT,                         -- Strategy name (for strategy-specific analysis)
    
    -- Indexes for performance
    UNIQUE(pattern_type, duration_category, pair, strategy)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_duration_patterns_type ON duration_patterns(pattern_type);
CREATE INDEX IF NOT EXISTS idx_duration_patterns_category ON duration_patterns(duration_category);
CREATE INDEX IF NOT EXISTS idx_duration_patterns_profit_hour ON duration_patterns(profit_per_hour DESC);

-- =====================================================
-- 2. POPULATE TABLE: Duration-Based Patterns
-- =====================================================

-- Clear existing duration-based patterns
DELETE FROM duration_patterns WHERE pattern_type = 'duration_based';

-- Insert duration-based trade patterns
-- Based on actual implementation from trading_analytics_automation_final.py
INSERT INTO duration_patterns (
    pattern_type, duration_category, min_duration_minutes, 
    max_duration_minutes, trade_count, win_rate, avg_profit_pct,
    total_profit_abs, optimal_exit_timing_minutes, profit_per_hour, analysis_date
)
SELECT 
    'duration_based' as pattern_type,
    CASE 
        WHEN trade_duration <= 60 THEN 'scalp'
        WHEN trade_duration <= 480 THEN 'short_term'  
        WHEN trade_duration <= 1440 THEN 'day_trade'
        ELSE 'swing_trade'
    END as duration_category,
    MIN(trade_duration) as min_duration_minutes,
    MAX(trade_duration) as max_duration_minutes,
    COUNT(*) as trade_count,
    AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
    AVG(profit_pct) as avg_profit_pct,
    SUM(profit_abs) as total_profit_abs,
    AVG(trade_duration) as optimal_exit_timing_minutes,
    CASE 
        WHEN AVG(trade_duration) > 0 
        THEN AVG(profit_pct) / (AVG(trade_duration) / 60.0)
        ELSE 0 
    END as profit_per_hour,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0 AND trade_duration IS NOT NULL
GROUP BY 
    CASE 
        WHEN trade_duration <= 60 THEN 'scalp'
        WHEN trade_duration <= 480 THEN 'short_term'  
        WHEN trade_duration <= 1440 THEN 'day_trade'
        ELSE 'swing_trade'
    END
HAVING COUNT(*) >= 1;

-- =====================================================
-- 3. POPULATE TABLE: Duration Patterns by Pair
-- =====================================================

-- Clear existing pair-based duration patterns
DELETE FROM duration_patterns WHERE pattern_type = 'by_pair';

-- Insert duration patterns for each trading pair
INSERT INTO duration_patterns (
    pattern_type, pair, duration_category, min_duration_minutes,
    max_duration_minutes, trade_count, win_rate, avg_profit_pct,
    total_profit_abs, optimal_exit_timing_minutes, profit_per_hour, analysis_date
)
SELECT 
    'by_pair' as pattern_type,
    pair,
    CASE 
        WHEN trade_duration <= 60 THEN 'scalp'
        WHEN trade_duration <= 480 THEN 'short_term'
        WHEN trade_duration <= 1440 THEN 'day_trade'
        ELSE 'swing_trade'
    END as duration_category,
    MIN(trade_duration) as min_duration_minutes,
    MAX(trade_duration) as max_duration_minutes,
    COUNT(*) as trade_count,
    AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
    AVG(profit_pct) as avg_profit_pct,
    SUM(profit_abs) as total_profit_abs,
    AVG(trade_duration) as optimal_exit_timing_minutes,
    CASE 
        WHEN AVG(trade_duration) > 0 
        THEN AVG(profit_pct) / (AVG(trade_duration) / 60.0)
        ELSE 0 
    END as profit_per_hour,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0 AND trade_duration IS NOT NULL
GROUP BY 
    pair,
    CASE 
        WHEN trade_duration <= 60 THEN 'scalp'
        WHEN trade_duration <= 480 THEN 'short_term'
        WHEN trade_duration <= 1440 THEN 'day_trade'
        ELSE 'swing_trade'
    END
HAVING COUNT(*) >= 2;  -- Only include combinations with meaningful data

-- =====================================================
-- 4. POPULATE TABLE: Duration Patterns by Strategy
-- =====================================================

-- Clear existing strategy-based duration patterns
DELETE FROM duration_patterns WHERE pattern_type = 'by_strategy';

-- Insert duration patterns for each strategy
INSERT INTO duration_patterns (
    pattern_type, strategy, duration_category, min_duration_minutes,
    max_duration_minutes, trade_count, win_rate, avg_profit_pct,
    total_profit_abs, optimal_exit_timing_minutes, profit_per_hour, analysis_date
)
SELECT 
    'by_strategy' as pattern_type,
    strategy,
    CASE 
        WHEN trade_duration <= 60 THEN 'scalp'
        WHEN trade_duration <= 480 THEN 'short_term'
        WHEN trade_duration <= 1440 THEN 'day_trade'
        ELSE 'swing_trade'
    END as duration_category,
    MIN(trade_duration) as min_duration_minutes,
    MAX(trade_duration) as max_duration_minutes,
    COUNT(*) as trade_count,
    AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
    AVG(profit_pct) as avg_profit_pct,
    SUM(profit_abs) as total_profit_abs,
    AVG(trade_duration) as optimal_exit_timing_minutes,
    CASE 
        WHEN AVG(trade_duration) > 0 
        THEN AVG(profit_pct) / (AVG(trade_duration) / 60.0)
        ELSE 0 
    END as profit_per_hour,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0 AND trade_duration IS NOT NULL
GROUP BY 
    strategy,
    CASE 
        WHEN trade_duration <= 60 THEN 'scalp'
        WHEN trade_duration <= 480 THEN 'short_term'
        WHEN trade_duration <= 1440 THEN 'day_trade'
        ELSE 'swing_trade'
    END
HAVING COUNT(*) >= 3;  -- Only include combinations with meaningful data

-- =====================================================
-- 5. QUERY EXAMPLES: Duration Pattern Analysis
-- =====================================================

-- Overall duration category performance
SELECT 
    duration_category,
    trade_count,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(total_profit_abs, 2) as total_profit,
    ROUND(optimal_exit_timing_minutes, 0) as avg_duration_min,
    ROUND(profit_per_hour, 3) as profit_per_hour,
    ROUND(min_duration_minutes, 0) as min_duration_min,
    ROUND(max_duration_minutes, 0) as max_duration_min
FROM duration_patterns 
WHERE pattern_type = 'duration_based'
ORDER BY profit_per_hour DESC;

-- Best performing duration categories by efficiency
SELECT 
    duration_category,
    trade_count,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(profit_per_hour, 3) as profit_per_hour,
    ROUND(optimal_exit_timing_minutes / 60.0, 1) as avg_duration_hours,
    CASE 
        WHEN profit_per_hour >= 1.0 THEN 'Highly Efficient'
        WHEN profit_per_hour >= 0.5 THEN 'Moderately Efficient'
        WHEN profit_per_hour >= 0.1 THEN 'Low Efficiency'
        ELSE 'Inefficient'
    END as efficiency_rating
FROM duration_patterns 
WHERE pattern_type = 'duration_based'
ORDER BY profit_per_hour DESC;

-- Duration patterns by pair (top performers)
SELECT 
    pair,
    duration_category,
    trade_count,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(profit_per_hour, 3) as profit_per_hour,
    ROUND(optimal_exit_timing_minutes, 0) as optimal_timing_min
FROM duration_patterns 
WHERE pattern_type = 'by_pair'
  AND trade_count >= 3
ORDER BY profit_per_hour DESC
LIMIT 20;

-- Duration patterns by strategy
SELECT 
    strategy,
    duration_category,
    trade_count,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(profit_per_hour, 3) as profit_per_hour,
    ROUND(optimal_exit_timing_minutes / 60.0, 1) as optimal_timing_hours
FROM duration_patterns 
WHERE pattern_type = 'by_strategy'
ORDER BY strategy, profit_per_hour DESC;

-- =====================================================
-- 6. ANALYTICS QUERIES: Duration Insights
-- =====================================================

-- Efficiency comparison across duration categories
SELECT 
    'Duration Efficiency Analysis' as analysis_type,
    duration_category,
    trade_count,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(optimal_exit_timing_minutes, 0) as avg_duration_min,
    ROUND(profit_per_hour, 3) as profit_per_hour,
    RANK() OVER (ORDER BY profit_per_hour DESC) as efficiency_rank
FROM duration_patterns 
WHERE pattern_type = 'duration_based'
ORDER BY profit_per_hour DESC;

-- Win rate vs Duration correlation
SELECT 
    duration_category,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(optimal_exit_timing_minutes / 60.0, 1) as avg_duration_hours,
    trade_count,
    CASE 
        WHEN win_rate >= 0.7 AND avg_profit_pct >= 1.0 THEN 'High Performance'
        WHEN win_rate >= 0.6 AND avg_profit_pct >= 0.5 THEN 'Good Performance'
        WHEN win_rate >= 0.5 THEN 'Average Performance'
        ELSE 'Below Average'
    END as performance_rating
FROM duration_patterns 
WHERE pattern_type = 'duration_based'
ORDER BY win_rate DESC, avg_profit_pct DESC;

-- Optimal duration ranges by pair
SELECT 
    pair,
    COUNT(DISTINCT duration_category) as categories_traded,
    MAX(CASE WHEN duration_category = 'scalp' THEN profit_per_hour END) as scalp_efficiency,
    MAX(CASE WHEN duration_category = 'short_term' THEN profit_per_hour END) as short_efficiency,
    MAX(CASE WHEN duration_category = 'day_trade' THEN profit_per_hour END) as day_efficiency,
    MAX(CASE WHEN duration_category = 'swing_trade' THEN profit_per_hour END) as swing_efficiency,
    CASE 
        WHEN MAX(profit_per_hour) = MAX(CASE WHEN duration_category = 'scalp' THEN profit_per_hour END) THEN 'scalp'
        WHEN MAX(profit_per_hour) = MAX(CASE WHEN duration_category = 'short_term' THEN profit_per_hour END) THEN 'short_term'
        WHEN MAX(profit_per_hour) = MAX(CASE WHEN duration_category = 'day_trade' THEN profit_per_hour END) THEN 'day_trade'
        ELSE 'swing_trade'
    END as optimal_duration_category
FROM duration_patterns 
WHERE pattern_type = 'by_pair'
GROUP BY pair
HAVING categories_traded >= 2
ORDER BY MAX(profit_per_hour) DESC;

-- Duration distribution analysis
SELECT 
    CASE 
        WHEN optimal_exit_timing_minutes <= 30 THEN 'Ultra Short (≤30min)'
        WHEN optimal_exit_timing_minutes <= 120 THEN 'Short (30min-2h)'
        WHEN optimal_exit_timing_minutes <= 480 THEN 'Medium (2h-8h)'
        WHEN optimal_exit_timing_minutes <= 1440 THEN 'Long (8h-1d)'
        ELSE 'Very Long (>1d)'
    END as timing_range,
    COUNT(*) as pattern_count,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(win_rate) * 100, 1) as avg_win_rate_pct,
    ROUND(AVG(profit_per_hour), 3) as avg_profit_per_hour,
    SUM(trade_count) as total_trades_in_range
FROM duration_patterns 
WHERE pattern_type = 'by_pair'
GROUP BY 
    CASE 
        WHEN optimal_exit_timing_minutes <= 30 THEN 'Ultra Short (≤30min)'
        WHEN optimal_exit_timing_minutes <= 120 THEN 'Short (30min-2h)'
        WHEN optimal_exit_timing_minutes <= 480 THEN 'Medium (2h-8h)'
        WHEN optimal_exit_timing_minutes <= 1440 THEN 'Long (8h-1d)'
        ELSE 'Very Long (>1d)'
    END
ORDER BY avg_profit_per_hour DESC;

-- =====================================================
-- 7. ADVANCED DURATION ANALYSIS
-- =====================================================

-- Most profitable duration windows by hour ranges
SELECT 
    CASE 
        WHEN optimal_exit_timing_minutes <= 60 THEN '0-1 hours'
        WHEN optimal_exit_timing_minutes <= 240 THEN '1-4 hours'
        WHEN optimal_exit_timing_minutes <= 720 THEN '4-12 hours'
        WHEN optimal_exit_timing_minutes <= 1440 THEN '12-24 hours'
        ELSE '1+ days'
    END as duration_window,
    COUNT(*) as pattern_count,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(win_rate) * 100, 1) as avg_win_rate_pct,
    ROUND(SUM(total_profit_abs), 2) as total_profit_in_window,
    ROUND(AVG(profit_per_hour), 3) as avg_efficiency
FROM duration_patterns 
WHERE pattern_type = 'by_pair'
GROUP BY 
    CASE 
        WHEN optimal_exit_timing_minutes <= 60 THEN '0-1 hours'
        WHEN optimal_exit_timing_minutes <= 240 THEN '1-4 hours'
        WHEN optimal_exit_timing_minutes <= 720 THEN '4-12 hours'
        WHEN optimal_exit_timing_minutes <= 1440 THEN '12-24 hours'
        ELSE '1+ days'
    END
ORDER BY avg_efficiency DESC;

-- Strategy efficiency by duration category
SELECT 
    strategy,
    COUNT(DISTINCT duration_category) as duration_categories_used,
    ROUND(AVG(avg_profit_pct), 2) as overall_avg_profit,
    ROUND(AVG(profit_per_hour), 3) as overall_efficiency,
    MAX(profit_per_hour) as best_efficiency,
    MIN(profit_per_hour) as worst_efficiency,
    ROUND((MAX(profit_per_hour) - MIN(profit_per_hour)), 3) as efficiency_range
FROM duration_patterns 
WHERE pattern_type = 'by_strategy'
GROUP BY strategy
HAVING duration_categories_used >= 2
ORDER BY overall_efficiency DESC;

-- Duration category performance matrix
SELECT 
    dp.duration_category,
    COUNT(DISTINCT dp.pair) as pairs_using_duration,
    ROUND(AVG(dp.avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(dp.win_rate) * 100, 1) as avg_win_rate_pct,
    ROUND(AVG(dp.profit_per_hour), 3) as avg_efficiency,
    SUM(dp.trade_count) as total_trades,
    ROUND(SUM(dp.total_profit_abs), 2) as total_profit_generated
FROM duration_patterns dp
WHERE dp.pattern_type = 'by_pair'
GROUP BY dp.duration_category
ORDER BY avg_efficiency DESC;

-- =====================================================
-- 8. DIRECT TRADES TABLE DURATION ANALYSIS
-- =====================================================

-- Quick duration analysis directly from trades table
SELECT 
    CASE 
        WHEN trade_duration <= 60 THEN 'Scalp (≤1h)'
        WHEN trade_duration <= 480 THEN 'Short (1-8h)'
        WHEN trade_duration <= 1440 THEN 'Day (8-24h)'
        ELSE 'Swing (>24h)'
    END as duration_category,
    COUNT(*) as trade_count,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) * 100, 1) as win_rate_pct,
    ROUND(MIN(trade_duration), 0) as min_duration_min,
    ROUND(MAX(trade_duration), 0) as max_duration_min,
    ROUND(AVG(trade_duration), 0) as avg_duration_min,
    ROUND(AVG(profit_pct) / (AVG(trade_duration) / 60.0), 3) as profit_per_hour
FROM trades 
WHERE is_open = 0 AND trade_duration IS NOT NULL
GROUP BY 
    CASE 
        WHEN trade_duration <= 60 THEN 'Scalp (≤1h)'
        WHEN trade_duration <= 480 THEN 'Short (1-8h)'
        WHEN trade_duration <= 1440 THEN 'Day (8-24h)'
        ELSE 'Swing (>24h)'
    END
ORDER BY profit_per_hour DESC;

-- Duration vs Profit correlation by individual trades
SELECT 
    ROUND(trade_duration / 60.0, 1) as duration_hours,
    COUNT(*) as trades_at_duration,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(MIN(profit_pct), 2) as min_profit_pct,
    ROUND(MAX(profit_pct), 2) as max_profit_pct
FROM trades 
WHERE is_open = 0 
  AND trade_duration IS NOT NULL
  AND trade_duration <= 2880  -- Focus on trades under 48 hours
GROUP BY ROUND(trade_duration / 60.0, 1)
HAVING trades_at_duration >= 2
ORDER BY duration_hours;

-- Exit timing effectiveness analysis
SELECT 
    pair,
    COUNT(*) as total_trades,
    ROUND(AVG(trade_duration), 0) as avg_duration_min,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(MIN(trade_duration), 0) as fastest_exit_min,
    ROUND(MAX(trade_duration), 0) as slowest_exit_min,
    ROUND((MAX(trade_duration) - MIN(trade_duration)), 0) as duration_range_min,
    COUNT(DISTINCT ROUND(trade_duration / 60.0, 0)) as distinct_duration_hours
FROM trades 
WHERE is_open = 0 
  AND trade_duration IS NOT NULL
GROUP BY pair
HAVING total_trades >= 5
ORDER BY avg_profit_pct DESC
LIMIT 15;

-- =====================================================
-- 9. MAINTENANCE QUERIES
-- =====================================================

-- Recalculate all duration patterns
DELETE FROM duration_patterns;

-- Re-run INSERT statements from sections 2, 3, and 4
-- ... (Would typically be executed by automation system)

-- Data quality check for duration patterns
SELECT 
    'Duration Patterns Quality Check' as check_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN avg_profit_pct IS NULL THEN 1 END) as null_profit_count,
    COUNT(CASE WHEN optimal_exit_timing_minutes IS NULL THEN 1 END) as null_timing_count,
    COUNT(CASE WHEN profit_per_hour IS NULL THEN 1 END) as null_efficiency_count,
    COUNT(CASE WHEN trade_count < 1 THEN 1 END) as invalid_trade_count,
    COUNT(CASE WHEN min_duration_minutes > max_duration_minutes THEN 1 END) as duration_logic_errors
FROM duration_patterns;