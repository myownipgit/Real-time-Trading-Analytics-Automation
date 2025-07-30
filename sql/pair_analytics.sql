-- Pair Analytics SQL
-- Purpose: Individual trading pair performance analysis
-- Data Source: ~/db_dev/trading_test.db trades table
-- Key Metrics: Individual pair metrics, currency analysis, volatility patterns

-- =====================================================
-- 1. CREATE TABLE: pair_analytics
-- =====================================================

CREATE TABLE IF NOT EXISTS pair_analytics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pair TEXT NOT NULL,                     -- Trading pair (e.g., 'BTC/USDT')
    base_currency TEXT,                     -- Base currency (e.g., 'BTC')
    quote_currency TEXT,                    -- Quote currency (e.g., 'USDT')
    total_trades INTEGER,                   -- Total number of trades for this pair
    winning_trades INTEGER,                 -- Number of profitable trades
    losing_trades INTEGER,                  -- Number of losing trades
    win_rate REAL,                         -- Win rate (0.0 to 1.0)
    avg_profit_pct REAL,                   -- Average profit percentage
    total_profit_abs REAL,                 -- Total absolute profit
    avg_trade_duration_minutes REAL,       -- Average trade duration
    price_volatility_pct REAL,             -- Price volatility measure
    best_trade_pct REAL,                   -- Best single trade percentage
    worst_trade_pct REAL,                  -- Worst single trade percentage
    total_volume REAL,                     -- Total volume (stake amount)
    avg_stake_amount REAL,                 -- Average stake per trade
    max_consecutive_wins INTEGER,          -- Longest winning streak
    max_consecutive_losses INTEGER,        -- Longest losing streak
    profit_factor REAL,                    -- Gross profit / Gross loss
    sharpe_ratio REAL,                     -- Risk-adjusted return metric
    analysis_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for performance
    UNIQUE(pair)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_pair_analytics_pair ON pair_analytics(pair);
CREATE INDEX IF NOT EXISTS idx_pair_analytics_base ON pair_analytics(base_currency);  
CREATE INDEX IF NOT EXISTS idx_pair_analytics_quote ON pair_analytics(quote_currency);
CREATE INDEX IF NOT EXISTS idx_pair_analytics_profit ON pair_analytics(avg_profit_pct DESC);

-- =====================================================
-- 2. POPULATE TABLE: Core Pair Metrics
-- =====================================================

-- Clear existing data and recalculate
DELETE FROM pair_analytics;

-- Insert core pair analytics metrics
-- Based on actual implementation from trading_analytics_automation_final.py
INSERT INTO pair_analytics (
    pair, base_currency, quote_currency, total_trades, 
    winning_trades, losing_trades, win_rate, avg_profit_pct,
    total_profit_abs, avg_trade_duration_minutes, price_volatility_pct,
    best_trade_pct, worst_trade_pct, total_volume, avg_stake_amount,
    profit_factor, analysis_date
)
SELECT 
    pair,
    base_currency,
    quote_currency,
    COUNT(*) as total_trades,
    SUM(CASE WHEN profit_pct > 0 THEN 1 ELSE 0 END) as winning_trades,
    SUM(CASE WHEN profit_pct <= 0 THEN 1 ELSE 0 END) as losing_trades,
    AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
    AVG(profit_pct) as avg_profit_pct,
    SUM(profit_abs) as total_profit_abs,
    AVG(trade_duration) as avg_trade_duration_minutes,
    CASE 
        WHEN COUNT(*) > 1
        THEN SQRT(AVG(profit_pct * profit_pct) - AVG(profit_pct) * AVG(profit_pct))
        ELSE 0
    END as price_volatility_pct,
    MAX(profit_pct) as best_trade_pct,
    MIN(profit_pct) as worst_trade_pct,
    SUM(stake_amount) as total_volume,
    AVG(stake_amount) as avg_stake_amount,
    CASE 
        WHEN SUM(CASE WHEN profit_abs < 0 THEN ABS(profit_abs) ELSE 0 END) > 0
        THEN SUM(CASE WHEN profit_abs > 0 THEN profit_abs ELSE 0 END) / 
             SUM(CASE WHEN profit_abs < 0 THEN ABS(profit_abs) ELSE 0 END)
        ELSE 0
    END as profit_factor,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0 
GROUP BY pair, base_currency, quote_currency
HAVING COUNT(*) >= 1;  -- Include all pairs with at least 1 trade

-- =====================================================
-- 3. UPDATE TABLE: Advanced Pair Metrics
-- =====================================================

-- Calculate consecutive wins/losses for each pair
UPDATE pair_analytics SET
    max_consecutive_wins = (
        SELECT MAX(consecutive_count) 
        FROM (
            SELECT pair, COUNT(*) as consecutive_count
            FROM (
                SELECT pair, profit_pct,
                       ROW_NUMBER() OVER (PARTITION BY pair ORDER BY trade_id) - 
                       ROW_NUMBER() OVER (PARTITION BY pair, CASE WHEN profit_pct > 0 THEN 1 ELSE 0 END ORDER BY trade_id) as grp
                FROM trades 
                WHERE is_open = 0 AND pair = pair_analytics.pair
            ) grouped
            WHERE profit_pct > 0
            GROUP BY pair, grp
        ) wins_streaks
    ),
    max_consecutive_losses = (
        SELECT MAX(consecutive_count) 
        FROM (
            SELECT pair, COUNT(*) as consecutive_count
            FROM (
                SELECT pair, profit_pct,
                       ROW_NUMBER() OVER (PARTITION BY pair ORDER BY trade_id) - 
                       ROW_NUMBER() OVER (PARTITION BY pair, CASE WHEN profit_pct <= 0 THEN 1 ELSE 0 END ORDER BY trade_id) as grp
                FROM trades 
                WHERE is_open = 0 AND pair = pair_analytics.pair
            ) grouped
            WHERE profit_pct <= 0
            GROUP BY pair, grp
        ) loss_streaks
    );

-- Calculate Sharpe ratio (simplified - assumes risk-free rate of 0)
UPDATE pair_analytics SET
    sharpe_ratio = (
        SELECT 
            CASE 
                WHEN SQRT(AVG(profit_pct * profit_pct) - AVG(profit_pct) * AVG(profit_pct)) > 0
                THEN AVG(profit_pct) / SQRT(AVG(profit_pct * profit_pct) - AVG(profit_pct) * AVG(profit_pct))
                ELSE 0
            END
        FROM trades 
        WHERE is_open = 0 AND pair = pair_analytics.pair
        HAVING COUNT(*) > 1
    )
WHERE total_trades > 1;

-- =====================================================
-- 4. QUERY EXAMPLES: Pair Analytics
-- =====================================================

-- Top performing pairs comprehensive view
SELECT 
    pair,
    base_currency,
    quote_currency,
    total_trades,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(total_profit_abs, 2) as total_profit,
    ROUND(price_volatility_pct, 2) as volatility_pct,
    ROUND(profit_factor, 2) as profit_factor,
    ROUND(avg_trade_duration_minutes, 0) as avg_duration_min
FROM pair_analytics 
ORDER BY avg_profit_pct DESC
LIMIT 15;

-- Worst performing pairs (need attention)
SELECT 
    pair,
    total_trades,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(worst_trade_pct, 2) as worst_trade_pct,
    max_consecutive_losses
FROM pair_analytics 
WHERE total_trades >= 3
ORDER BY avg_profit_pct ASC
LIMIT 10;

-- High volume pairs
SELECT 
    pair,
    total_trades,
    ROUND(total_volume, 2) as total_volume,
    ROUND(avg_stake_amount, 2) as avg_stake_per_trade,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(total_profit_abs, 2) as total_profit
FROM pair_analytics 
ORDER BY total_volume DESC
LIMIT 10;

-- Most consistent pairs (low volatility, good performance)
SELECT 
    pair,
    total_trades,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(price_volatility_pct, 2) as volatility_pct,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(sharpe_ratio, 3) as sharpe_ratio
FROM pair_analytics 
WHERE total_trades >= 5
  AND avg_profit_pct > 0
ORDER BY sharpe_ratio DESC, price_volatility_pct ASC
LIMIT 10;

-- =====================================================
-- 5. ANALYTICS QUERIES: Currency Analysis
-- =====================================================

-- Base currency performance summary
SELECT 
    base_currency,
    COUNT(*) as pair_count,
    SUM(total_trades) as total_trades,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(win_rate) * 100, 1) as avg_win_rate_pct,
    ROUND(SUM(total_profit_abs), 2) as total_profit,
    ROUND(SUM(total_volume), 2) as total_volume_traded,
    ROUND(AVG(price_volatility_pct), 2) as avg_volatility_pct
FROM pair_analytics 
GROUP BY base_currency
HAVING pair_count >= 2  -- Only currencies with multiple pairs
ORDER BY avg_profit_pct DESC;

-- Quote currency performance summary
SELECT 
    quote_currency,
    COUNT(*) as pair_count,
    SUM(total_trades) as total_trades,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(win_rate) * 100, 1) as avg_win_rate_pct,
    ROUND(SUM(total_profit_abs), 2) as total_profit,
    ROUND(SUM(total_volume), 2) as total_volume_traded
FROM pair_analytics 
GROUP BY quote_currency
ORDER BY total_volume_traded DESC;

-- Cross-currency analysis (which base/quote combinations work best)
SELECT 
    base_currency || '/' || quote_currency as currency_combo,
    COUNT(*) as pair_count,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(win_rate) * 100, 1) as avg_win_rate_pct,
    SUM(total_trades) as total_trades,
    ROUND(AVG(price_volatility_pct), 2) as avg_volatility_pct
FROM pair_analytics 
GROUP BY base_currency, quote_currency
HAVING pair_count >= 1
ORDER BY avg_profit_pct DESC;

-- =====================================================
-- 6. ANALYTICS QUERIES: Performance Insights
-- =====================================================

-- Volatility vs Performance analysis
SELECT 
    CASE 
        WHEN price_volatility_pct >= 5 THEN 'High Volatility (≥5%)'
        WHEN price_volatility_pct >= 3 THEN 'Medium Volatility (3-5%)'
        WHEN price_volatility_pct >= 1 THEN 'Low Volatility (1-3%)'
        ELSE 'Very Low Volatility (<1%)'
    END as volatility_category,
    COUNT(*) as pair_count,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(price_volatility_pct), 2) as avg_volatility,
    ROUND(AVG(win_rate) * 100, 1) as avg_win_rate_pct,
    ROUND(AVG(sharpe_ratio), 3) as avg_sharpe_ratio
FROM pair_analytics 
WHERE price_volatility_pct IS NOT NULL
GROUP BY 
    CASE 
        WHEN price_volatility_pct >= 5 THEN 'High Volatility (≥5%)'
        WHEN price_volatility_pct >= 3 THEN 'Medium Volatility (3-5%)'
        WHEN price_volatility_pct >= 1 THEN 'Low Volatility (1-3%)'
        ELSE 'Very Low Volatility (<1%)'
    END
ORDER BY avg_profit_pct DESC;

-- Trade frequency vs Performance
SELECT 
    CASE 
        WHEN total_trades >= 20 THEN 'High Frequency (≥20 trades)'
        WHEN total_trades >= 10 THEN 'Medium Frequency (10-19 trades)'
        WHEN total_trades >= 5 THEN 'Low Frequency (5-9 trades)'
        ELSE 'Very Low Frequency (<5 trades)'
    END as frequency_category,
    COUNT(*) as pair_count,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(total_trades), 1) as avg_trades_per_pair,
    ROUND(AVG(win_rate) * 100, 1) as avg_win_rate_pct,
    ROUND(SUM(total_profit_abs), 2) as category_total_profit
FROM pair_analytics 
GROUP BY 
    CASE 
        WHEN total_trades >= 20 THEN 'High Frequency (≥20 trades)'
        WHEN total_trades >= 10 THEN 'Medium Frequency (10-19 trades)'
        WHEN total_trades >= 5 THEN 'Low Frequency (5-9 trades)'
        ELSE 'Very Low Frequency (<5 trades)'
    END
ORDER BY avg_profit_pct DESC;

-- Win rate distribution by pairs
SELECT 
    CASE 
        WHEN win_rate >= 0.8 THEN 'Excellent Win Rate (≥80%)'
        WHEN win_rate >= 0.6 THEN 'Good Win Rate (60-80%)'
        WHEN win_rate >= 0.4 THEN 'Average Win Rate (40-60%)'
        ELSE 'Poor Win Rate (<40%)'
    END as win_rate_category,
    COUNT(*) as pair_count,
    ROUND(AVG(win_rate) * 100, 1) as avg_win_rate_pct,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(profit_factor), 2) as avg_profit_factor,
    ROUND(AVG(max_consecutive_losses), 1) as avg_max_loss_streak
FROM pair_analytics 
GROUP BY 
    CASE 
        WHEN win_rate >= 0.8 THEN 'Excellent Win Rate (≥80%)'
        WHEN win_rate >= 0.6 THEN 'Good Win Rate (60-80%)'
        WHEN win_rate >= 0.4 THEN 'Average Win Rate (40-60%)'
        ELSE 'Poor Win Rate (<40%)'
    END
ORDER BY avg_profit_pct DESC;

-- =====================================================
-- 7. PAIR COMPARISON QUERIES
-- =====================================================

-- Head-to-head pair comparison (top 2 pairs)
WITH top_pairs AS (
    SELECT pair, avg_profit_pct, total_trades, win_rate
    FROM pair_analytics
    ORDER BY avg_profit_pct DESC
    LIMIT 2
)
SELECT 
    'Pair Comparison' as analysis_type,
    (SELECT pair FROM top_pairs LIMIT 1) as best_pair,
    (SELECT ROUND(avg_profit_pct, 2) FROM top_pairs LIMIT 1) as best_profit_pct,
    (SELECT pair FROM top_pairs LIMIT 1 OFFSET 1) as second_pair,
    (SELECT ROUND(avg_profit_pct, 2) FROM top_pairs LIMIT 1 OFFSET 1) as second_profit_pct,
    ROUND((SELECT avg_profit_pct FROM top_pairs LIMIT 1) - 
          (SELECT avg_profit_pct FROM top_pairs LIMIT 1 OFFSET 1), 2) as profit_difference;

-- Pair efficiency analysis (profit per hour)
SELECT 
    pair,
    total_trades,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(avg_trade_duration_minutes, 0) as avg_duration_min,
    ROUND(avg_profit_pct / (avg_trade_duration_minutes / 60.0), 3) as profit_per_hour,
    ROUND(total_profit_abs / total_trades, 2) as profit_per_trade
FROM pair_analytics 
WHERE avg_trade_duration_minutes > 0
ORDER BY profit_per_hour DESC
LIMIT 15;

-- Risk-adjusted pair ranking
SELECT 
    pair,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(price_volatility_pct, 2) as volatility_pct,
    ROUND(sharpe_ratio, 3) as sharpe_ratio,
    ROUND(profit_factor, 2) as profit_factor,
    max_consecutive_losses,
    CASE 
        WHEN avg_profit_pct >= 1.5 AND sharpe_ratio >= 0.5 THEN 'Star Performer'
        WHEN avg_profit_pct >= 1.0 AND sharpe_ratio >= 0.3 THEN 'Solid Performer'
        WHEN avg_profit_pct >= 0.5 THEN 'Moderate Performer'
        WHEN avg_profit_pct >= 0.0 THEN 'Break-even'
        ELSE 'Underperformer'
    END as performance_rating
FROM pair_analytics 
WHERE total_trades >= 5
ORDER BY sharpe_ratio DESC, avg_profit_pct DESC;

-- =====================================================
-- 8. DIRECT TRADES TABLE PAIR ANALYSIS
-- =====================================================

-- Quick pair analysis directly from trades table
SELECT 
    pair,
    base_currency,
    quote_currency,
    COUNT(*) as total_trades,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) * 100, 1) as win_rate_pct,
    ROUND(MAX(profit_pct), 2) as best_trade_pct,
    ROUND(MIN(profit_pct), 2) as worst_trade_pct,
    ROUND(SUM(stake_amount), 2) as total_volume,
    ROUND(AVG(trade_duration), 0) as avg_duration_min,
    COUNT(DISTINCT DATE(open_date)) as trading_days
FROM trades 
WHERE is_open = 0
GROUP BY pair, base_currency, quote_currency
HAVING total_trades >= 3
ORDER BY avg_profit_pct DESC;

-- Pair performance by time period
SELECT 
    pair,
    strftime('%Y-%m', open_date) as month,
    COUNT(*) as trades_that_month,
    ROUND(AVG(profit_pct), 2) as monthly_avg_profit,
    ROUND(AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) * 100, 1) as monthly_win_rate
FROM trades 
WHERE is_open = 0 
  AND open_date IS NOT NULL
GROUP BY pair, strftime('%Y-%m', open_date)
HAVING trades_that_month >= 2
ORDER BY pair, month DESC;

-- =====================================================
-- 9. MAINTENANCE QUERIES
-- =====================================================

-- Recalculate all pair analytics
DELETE FROM pair_analytics;

-- Re-run INSERT statements from sections 2 and 3
-- ... (Would typically be executed by automation system)

-- Data quality check for pair analytics
SELECT 
    'Pair Analytics Quality Check' as check_type,
    COUNT(*) as total_pairs,
    COUNT(CASE WHEN avg_profit_pct IS NULL THEN 1 END) as null_profit_count,
    COUNT(CASE WHEN win_rate IS NULL THEN 1 END) as null_winrate_count,
    COUNT(CASE WHEN total_trades < 1 THEN 1 END) as invalid_trade_count,
    COUNT(CASE WHEN win_rate > 1.0 THEN 1 END) as invalid_winrate_count,
    COUNT(CASE WHEN base_currency IS NULL THEN 1 END) as null_base_currency_count
FROM pair_analytics;