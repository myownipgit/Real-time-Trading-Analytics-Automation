-- Timing Analysis SQL
-- Purpose: Identifies optimal trading times
-- Data Source: ~/db_dev/trading_test.db trades table
-- Key Metrics: Best/worst performance hours, weekend vs weekday performance

-- =====================================================
-- 1. CREATE TABLE: timing_analysis
-- =====================================================

CREATE TABLE IF NOT EXISTS timing_analysis (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    time_category TEXT NOT NULL,            -- 'overall', 'hourly', 'daily', 'monthly'
    trade_count INTEGER,                    -- Number of trades in this time period
    win_rate REAL,                         -- Win rate for this time period
    avg_profit_pct REAL,                   -- Average profit percentage
    total_profit_abs REAL,                 -- Total absolute profit
    best_performance_hour INTEGER,         -- Hour with best performance (0-23)
    worst_performance_hour INTEGER,        -- Hour with worst performance (0-23)
    weekend_performance_pct REAL,          -- Weekend average performance
    weekday_performance_pct REAL,          -- Weekday average performance
    duration_minutes_avg REAL,             -- Average trade duration in minutes
    volatility_pct REAL,                   -- Price volatility during period
    analysis_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Optional time-specific fields
    hour_of_day INTEGER,                   -- Specific hour (0-23) for hourly analysis
    day_of_week INTEGER,                   -- Day of week (0=Sunday, 6=Saturday) 
    day_of_month INTEGER,                  -- Day of month (1-31)
    month_of_year INTEGER,                 -- Month (1-12)
    time_period_name TEXT,                 -- Human readable time period name
    
    -- Indexes for performance
    UNIQUE(time_category, hour_of_day, day_of_week, day_of_month, month_of_year)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_timing_analysis_category ON timing_analysis(time_category);
CREATE INDEX IF NOT EXISTS idx_timing_analysis_hour ON timing_analysis(hour_of_day);
CREATE INDEX IF NOT EXISTS idx_timing_analysis_profit ON timing_analysis(avg_profit_pct DESC);

-- =====================================================
-- 2. POPULATE TABLE: Overall Timing Analysis
-- =====================================================

-- Clear existing overall analysis
DELETE FROM timing_analysis WHERE time_category = 'overall';

-- First, get hourly performance data to determine best/worst hours
-- Based on actual implementation from trading_analytics_automation_final.py
WITH hourly_performance AS (
    SELECT 
        CAST(strftime('%H', open_date) AS INTEGER) as hour,
        COUNT(*) as trade_count,
        AVG(profit_pct) as avg_profit_pct,
        AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
        AVG(trade_duration) as avg_duration
    FROM trades 
    WHERE is_open = 0 AND open_date IS NOT NULL
    GROUP BY strftime('%H', open_date)
    ORDER BY avg_profit_pct DESC
),
period_performance AS (
    SELECT 
        CASE WHEN strftime('%w', open_date) IN ('0', '6') THEN 'weekend' ELSE 'weekday' END as period_type,
        AVG(profit_pct) as avg_profit_pct
    FROM trades 
    WHERE is_open = 0 AND open_date IS NOT NULL
    GROUP BY CASE WHEN strftime('%w', open_date) IN ('0', '6') THEN 'weekend' ELSE 'weekday' END
)
INSERT INTO timing_analysis (
    time_category, trade_count, win_rate, avg_profit_pct,
    total_profit_abs, best_performance_hour, worst_performance_hour,
    weekend_performance_pct, weekday_performance_pct,
    duration_minutes_avg, analysis_date
)
SELECT 
    'overall' as time_category,
    COUNT(*) as trade_count,
    AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
    AVG(profit_pct) as avg_profit_pct,
    SUM(profit_abs) as total_profit_abs,
    (SELECT hour FROM hourly_performance ORDER BY avg_profit_pct DESC LIMIT 1) as best_performance_hour,
    (SELECT hour FROM hourly_performance ORDER BY avg_profit_pct ASC LIMIT 1) as worst_performance_hour,
    (SELECT avg_profit_pct FROM period_performance WHERE period_type = 'weekend') as weekend_performance_pct,
    (SELECT avg_profit_pct FROM period_performance WHERE period_type = 'weekday') as weekday_performance_pct,
    AVG(trade_duration) as duration_minutes_avg,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0;

-- =====================================================
-- 3. POPULATE TABLE: Hourly Analysis
-- =====================================================

-- Clear existing hourly analysis
DELETE FROM timing_analysis WHERE time_category = 'hourly';

-- Insert detailed hourly performance
INSERT INTO timing_analysis (
    time_category, hour_of_day, time_period_name, trade_count, 
    win_rate, avg_profit_pct, total_profit_abs, 
    duration_minutes_avg, volatility_pct, analysis_date
)
SELECT 
    'hourly' as time_category,
    CAST(strftime('%H', open_date) AS INTEGER) as hour_of_day,
    CASE 
        WHEN CAST(strftime('%H', open_date) AS INTEGER) BETWEEN 0 AND 5 THEN 'Early Morning (0-5)'
        WHEN CAST(strftime('%H', open_date) AS INTEGER) BETWEEN 6 AND 11 THEN 'Morning (6-11)'
        WHEN CAST(strftime('%H', open_date) AS INTEGER) BETWEEN 12 AND 17 THEN 'Afternoon (12-17)'
        WHEN CAST(strftime('%H', open_date) AS INTEGER) BETWEEN 18 AND 23 THEN 'Evening (18-23)'
    END as time_period_name,
    COUNT(*) as trade_count,
    AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
    AVG(profit_pct) as avg_profit_pct,
    SUM(profit_abs) as total_profit_abs,
    AVG(trade_duration) as duration_minutes_avg,
    CASE 
        WHEN COUNT(*) > 1 
        THEN SQRT(AVG(profit_pct * profit_pct) - AVG(profit_pct) * AVG(profit_pct))
        ELSE 0 
    END as volatility_pct,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0 AND open_date IS NOT NULL
GROUP BY strftime('%H', open_date)
HAVING COUNT(*) >= 1;

-- =====================================================
-- 4. POPULATE TABLE: Daily Analysis
-- =====================================================

-- Clear existing daily analysis
DELETE FROM timing_analysis WHERE time_category = 'daily';

-- Insert daily performance (day of week analysis)
INSERT INTO timing_analysis (
    time_category, day_of_week, time_period_name, trade_count,
    win_rate, avg_profit_pct, total_profit_abs,
    duration_minutes_avg, analysis_date
)
SELECT 
    'daily' as time_category,
    CAST(strftime('%w', open_date) AS INTEGER) as day_of_week,
    CASE CAST(strftime('%w', open_date) AS INTEGER)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END as time_period_name,
    COUNT(*) as trade_count,
    AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
    AVG(profit_pct) as avg_profit_pct,
    SUM(profit_abs) as total_profit_abs,
    AVG(trade_duration) as duration_minutes_avg,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0 AND open_date IS NOT NULL
GROUP BY strftime('%w', open_date)
HAVING COUNT(*) >= 1;

-- =====================================================
-- 5. POPULATE TABLE: Monthly Analysis
-- =====================================================

-- Clear existing monthly analysis
DELETE FROM timing_analysis WHERE time_category = 'monthly';

-- Insert monthly performance analysis
INSERT INTO timing_analysis (
    time_category, month_of_year, time_period_name, trade_count,
    win_rate, avg_profit_pct, total_profit_abs,
    duration_minutes_avg, analysis_date
)
SELECT 
    'monthly' as time_category,
    CAST(strftime('%m', open_date) AS INTEGER) as month_of_year,
    CASE CAST(strftime('%m', open_date) AS INTEGER)
        WHEN 1 THEN 'January' WHEN 2 THEN 'February' WHEN 3 THEN 'March'
        WHEN 4 THEN 'April' WHEN 5 THEN 'May' WHEN 6 THEN 'June'
        WHEN 7 THEN 'July' WHEN 8 THEN 'August' WHEN 9 THEN 'September'
        WHEN 10 THEN 'October' WHEN 11 THEN 'November' WHEN 12 THEN 'December'
    END as time_period_name,
    COUNT(*) as trade_count,
    AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
    AVG(profit_pct) as avg_profit_pct,
    SUM(profit_abs) as total_profit_abs,
    AVG(trade_duration) as duration_minutes_avg,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0 AND open_date IS NOT NULL
GROUP BY strftime('%m', open_date)
HAVING COUNT(*) >= 2;

-- =====================================================
-- 6. QUERY EXAMPLES: Timing Analysis
-- =====================================================

-- Overall timing summary
SELECT 
    time_category,
    trade_count,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    best_performance_hour,
    worst_performance_hour,
    ROUND(weekend_performance_pct, 2) as weekend_profit_pct,
    ROUND(weekday_performance_pct, 2) as weekday_profit_pct
FROM timing_analysis 
WHERE time_category = 'overall';

-- Best trading hours
SELECT 
    hour_of_day,
    time_period_name,
    trade_count,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(total_profit_abs, 2) as total_profit,
    ROUND(duration_minutes_avg, 0) as avg_duration_min
FROM timing_analysis 
WHERE time_category = 'hourly'
ORDER BY avg_profit_pct DESC;

-- Day of week performance
SELECT 
    time_period_name as day_name,
    day_of_week,
    trade_count,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(total_profit_abs, 2) as total_profit,
    CASE 
        WHEN day_of_week IN (0, 6) THEN 'Weekend'
        ELSE 'Weekday'
    END as period_type
FROM timing_analysis 
WHERE time_category = 'daily'
ORDER BY avg_profit_pct DESC;

-- Monthly seasonality
SELECT 
    time_period_name as month_name,
    month_of_year,
    trade_count,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(total_profit_abs, 2) as total_profit
FROM timing_analysis 
WHERE time_category = 'monthly'
ORDER BY month_of_year;

-- =====================================================
-- 7. ANALYTICS QUERIES: Timing Insights
-- =====================================================

-- Trading session analysis
SELECT 
    time_period_name as trading_session,
    COUNT(*) as hours_in_session,
    SUM(trade_count) as total_trades,
    ROUND(AVG(avg_profit_pct), 2) as session_avg_profit,
    ROUND(AVG(win_rate) * 100, 1) as session_avg_winrate,
    ROUND(SUM(total_profit_abs), 2) as session_total_profit
FROM timing_analysis 
WHERE time_category = 'hourly'
GROUP BY time_period_name
ORDER BY session_avg_profit DESC;

-- Weekend vs Weekday detailed comparison
SELECT 
    CASE 
        WHEN day_of_week IN (0, 6) THEN 'Weekend'
        ELSE 'Weekday'
    END as period_type,
    COUNT(*) as days_analyzed,
    SUM(trade_count) as total_trades,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(win_rate) * 100, 1) as avg_win_rate_pct,
    ROUND(SUM(total_profit_abs), 2) as total_profit,
    ROUND(AVG(duration_minutes_avg), 0) as avg_trade_duration
FROM timing_analysis 
WHERE time_category = 'daily'
GROUP BY CASE WHEN day_of_week IN (0, 6) THEN 'Weekend' ELSE 'Weekday' END
ORDER BY avg_profit_pct DESC;

-- Peak performance hours identification
SELECT 
    hour_of_day,
    time_period_name,
    ROUND(avg_profit_pct, 2) as profit_pct,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    trade_count,
    CASE 
        WHEN avg_profit_pct >= 1.5 THEN 'Excellent Hour'
        WHEN avg_profit_pct >= 1.0 THEN 'Good Hour'
        WHEN avg_profit_pct >= 0.5 THEN 'Average Hour'
        WHEN avg_profit_pct >= 0.0 THEN 'Break-even Hour'
        ELSE 'Poor Hour'
    END as hour_rating
FROM timing_analysis 
WHERE time_category = 'hourly'
ORDER BY avg_profit_pct DESC;

-- Time-based volatility analysis
SELECT 
    time_period_name,
    ROUND(AVG(volatility_pct), 2) as avg_volatility,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(volatility_pct) / NULLIF(AVG(avg_profit_pct), 0), 2) as volatility_to_profit_ratio,
    SUM(trade_count) as total_trades
FROM timing_analysis 
WHERE time_category = 'hourly' AND volatility_pct IS NOT NULL
GROUP BY time_period_name
ORDER BY avg_profit_pct DESC;

-- =====================================================
-- 8. ADVANCED TIMING ANALYSIS
-- =====================================================

-- Market opening/closing hours analysis (assuming UTC times)
SELECT 
    CASE 
        WHEN hour_of_day IN (13, 14, 15, 16, 17, 18, 19, 20) THEN 'US Market Hours (13-20 UTC)'
        WHEN hour_of_day IN (8, 9, 10, 11, 12, 13, 14, 15) THEN 'EU Market Hours (8-15 UTC)'
        WHEN hour_of_day IN (0, 1, 2, 3, 4, 5, 6, 7) THEN 'Asia Market Hours (0-7 UTC)'
        ELSE 'Off Market Hours'
    END as market_session,
    COUNT(DISTINCT hour_of_day) as hours_in_session,
    SUM(trade_count) as total_trades,
    ROUND(AVG(avg_profit_pct), 2) as session_avg_profit,
    ROUND(AVG(win_rate) * 100, 1) as session_win_rate,
    ROUND(SUM(total_profit_abs), 2) as session_total_profit
FROM timing_analysis 
WHERE time_category = 'hourly'
GROUP BY 
    CASE 
        WHEN hour_of_day IN (13, 14, 15, 16, 17, 18, 19, 20) THEN 'US Market Hours (13-20 UTC)'
        WHEN hour_of_day IN (8, 9, 10, 11, 12, 13, 14, 15) THEN 'EU Market Hours (8-15 UTC)'
        WHEN hour_of_day IN (0, 1, 2, 3, 4, 5, 6, 7) THEN 'Asia Market Hours (0-7 UTC)'
        ELSE 'Off Market Hours'
    END
ORDER BY session_avg_profit DESC;

-- Consecutive hour performance patterns
SELECT 
    t1.hour_of_day as current_hour,
    t2.hour_of_day as next_hour,
    ROUND(t1.avg_profit_pct, 2) as current_hour_profit,
    ROUND(t2.avg_profit_pct, 2) as next_hour_profit,
    t1.trade_count as current_hour_trades,
    t2.trade_count as next_hour_trades
FROM timing_analysis t1
LEFT JOIN timing_analysis t2 ON t2.hour_of_day = (t1.hour_of_day + 1) % 24
WHERE t1.time_category = 'hourly' AND t2.time_category = 'hourly'
ORDER BY t1.avg_profit_pct DESC
LIMIT 10;

-- =====================================================
-- 9. DIRECT TRADES TABLE TIMING ANALYSIS
-- =====================================================

-- Quick timing analysis directly from trades table
SELECT 
    'Timing Summary' as analysis_type,
    CAST(strftime('%H', open_date) AS INTEGER) as hour,
    COUNT(*) as trade_count,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) * 100, 1) as win_rate_pct,
    ROUND(SUM(profit_abs), 2) as total_profit,
    ROUND(AVG(trade_duration), 0) as avg_duration_min
FROM trades 
WHERE is_open = 0 AND open_date IS NOT NULL
GROUP BY strftime('%H', open_date)
HAVING trade_count >= 2
ORDER BY avg_profit_pct DESC
LIMIT 10;

-- Day of week analysis from trades table
SELECT 
    CASE CAST(strftime('%w', open_date) AS INTEGER)
        WHEN 0 THEN 'Sunday' WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday' WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END as day_name,
    CAST(strftime('%w', open_date) AS INTEGER) as day_number,
    COUNT(*) as trade_count,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) * 100, 1) as win_rate_pct,
    CASE 
        WHEN CAST(strftime('%w', open_date) AS INTEGER) IN (0, 6) THEN 'Weekend'
        ELSE 'Weekday'
    END as period_type
FROM trades 
WHERE is_open = 0 AND open_date IS NOT NULL
GROUP BY strftime('%w', open_date)
ORDER BY avg_profit_pct DESC;

-- =====================================================
-- 10. MAINTENANCE QUERIES
-- =====================================================

-- Recalculate all timing analysis
DELETE FROM timing_analysis;

-- Re-run INSERT statements from sections 2, 3, 4, and 5
-- ... (Would typically be executed by automation system)

-- Data quality check for timing analysis
SELECT 
    'Timing Analysis Quality Check' as check_type,
    COUNT(*) as total_records,
    COUNT(DISTINCT time_category) as categories_analyzed,
    COUNT(CASE WHEN avg_profit_pct IS NULL THEN 1 END) as null_profit_count,
    COUNT(CASE WHEN trade_count < 1 THEN 1 END) as invalid_trade_count,
    MIN(analysis_date) as oldest_analysis,
    MAX(analysis_date) as newest_analysis
FROM timing_analysis;