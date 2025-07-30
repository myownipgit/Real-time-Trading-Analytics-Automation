-- Performance Rankings SQL
-- Purpose: Ranks trading pairs by profitability
-- Data Source: ~/db_dev/trading_test.db trades table
-- Key Metrics: Win rate, profit percentage, trade count, profit ratios

-- =====================================================
-- 1. CREATE TABLE: performance_rankings
-- =====================================================

CREATE TABLE IF NOT EXISTS performance_rankings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ranking_type TEXT NOT NULL,              -- 'by_pair', 'by_strategy', etc.
    entity_name TEXT NOT NULL,               -- Trading pair name (e.g., 'BTC/USDT')
    entity_type TEXT NOT NULL,               -- 'trading_pair', 'strategy', etc.
    profit_ratio REAL,                       -- Average profit ratio (decimal)
    profit_pct REAL,                         -- Average profit percentage
    profit_abs REAL,                         -- Total absolute profit
    trade_count INTEGER,                     -- Number of trades
    win_rate REAL,                          -- Win rate (0.0 to 1.0)
    avg_duration_minutes REAL,              -- Average trade duration in minutes
    max_profit_pct REAL,                    -- Best trade profit percentage
    min_profit_pct REAL,                    -- Worst trade profit percentage
    total_volume REAL,                      -- Total volume traded (stake amount)
    rank_position INTEGER,                  -- Ranking position (1 = best)
    analysis_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for performance
    UNIQUE(ranking_type, entity_name, entity_type)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_performance_rankings_type ON performance_rankings(ranking_type);
CREATE INDEX IF NOT EXISTS idx_performance_rankings_rank ON performance_rankings(rank_position);
CREATE INDEX IF NOT EXISTS idx_performance_rankings_profit ON performance_rankings(profit_pct DESC);

-- =====================================================
-- 2. POPULATE TABLE: Trading Pair Rankings
-- =====================================================

-- Clear existing pair rankings and recalculate
DELETE FROM performance_rankings WHERE ranking_type = 'by_pair';

-- Insert trading pair performance rankings
-- Note: Uses actual schema from ~/db_dev/trading_test.db
INSERT INTO performance_rankings (
    ranking_type, entity_name, entity_type, profit_ratio, 
    profit_pct, profit_abs, trade_count, win_rate, 
    avg_duration_minutes, max_profit_pct, min_profit_pct,
    total_volume, rank_position, analysis_date
)
SELECT 
    'by_pair' as ranking_type,
    pair as entity_name,
    'trading_pair' as entity_type,
    AVG(profit_ratio) as profit_ratio,
    AVG(profit_pct) as profit_pct,
    SUM(profit_abs) as profit_abs,
    COUNT(*) as trade_count,
    AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
    AVG(trade_duration) as avg_duration_minutes,
    MAX(profit_pct) as max_profit_pct,
    MIN(profit_pct) as min_profit_pct,
    SUM(stake_amount) as total_volume,
    ROW_NUMBER() OVER (ORDER BY AVG(profit_pct) DESC) as rank_position,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0 
GROUP BY pair
HAVING COUNT(*) >= 1  -- Only include pairs with at least 1 trade
ORDER BY profit_pct DESC;

-- =====================================================
-- 3. QUERY EXAMPLES: Performance Rankings
-- =====================================================

-- Top 10 performing trading pairs
SELECT 
    rank_position,
    entity_name as trading_pair,
    ROUND(profit_pct, 2) as avg_profit_pct,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    trade_count,
    ROUND(total_volume, 2) as total_volume_usdt,
    ROUND(avg_duration_minutes, 0) as avg_duration_min
FROM performance_rankings 
WHERE ranking_type = 'by_pair'
ORDER BY rank_position ASC
LIMIT 10;

-- Bottom 5 performing pairs (need attention)
SELECT 
    rank_position,
    entity_name as trading_pair,
    ROUND(profit_pct, 2) as avg_profit_pct,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    trade_count,
    ROUND(min_profit_pct, 2) as worst_trade_pct
FROM performance_rankings 
WHERE ranking_type = 'by_pair'
ORDER BY rank_position DESC
LIMIT 5;

-- Pairs with high win rate but low profit (might have small gains)
SELECT 
    entity_name as trading_pair,
    ROUND(profit_pct, 2) as avg_profit_pct,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    trade_count,
    ROUND(max_profit_pct, 2) as best_trade_pct
FROM performance_rankings 
WHERE ranking_type = 'by_pair'
  AND win_rate >= 0.7  -- 70%+ win rate
  AND profit_pct < 1.0 -- but less than 1% average profit
ORDER BY win_rate DESC;

-- High volume pairs (most actively traded)
SELECT 
    entity_name as trading_pair,
    ROUND(profit_pct, 2) as avg_profit_pct,
    trade_count,
    ROUND(total_volume, 2) as total_volume_usdt,
    ROUND(total_volume / trade_count, 2) as avg_stake_per_trade
FROM performance_rankings 
WHERE ranking_type = 'by_pair'
ORDER BY total_volume DESC
LIMIT 10;

-- =====================================================
-- 4. ANALYTICS QUERIES: Key Insights
-- =====================================================

-- Overall portfolio performance summary  
SELECT 
    COUNT(*) as total_pairs_traded,
    ROUND(AVG(profit_pct), 2) as portfolio_avg_profit_pct,
    ROUND(AVG(win_rate) * 100, 1) as portfolio_avg_win_rate,
    SUM(trade_count) as total_trades,
    ROUND(SUM(profit_abs), 2) as total_profit_abs,
    ROUND(SUM(total_volume), 2) as total_volume_traded
FROM performance_rankings 
WHERE ranking_type = 'by_pair';

-- Performance distribution analysis
SELECT 
    CASE 
        WHEN profit_pct >= 2.0 THEN 'Excellent (≥2%)'
        WHEN profit_pct >= 1.0 THEN 'Good (1-2%)'
        WHEN profit_pct >= 0.0 THEN 'Break-even (0-1%)'
        ELSE 'Losing (<0%)'
    END as performance_category,
    COUNT(*) as pair_count,
    ROUND(AVG(profit_pct), 2) as avg_profit_in_category,
    ROUND(AVG(win_rate) * 100, 1) as avg_win_rate_in_category
FROM performance_rankings 
WHERE ranking_type = 'by_pair'
GROUP BY 
    CASE 
        WHEN profit_pct >= 2.0 THEN 'Excellent (≥2%)'
        WHEN profit_pct >= 1.0 THEN 'Good (1-2%)'
        WHEN profit_pct >= 0.0 THEN 'Break-even (0-1%)'
        ELSE 'Losing (<0%)'
    END
ORDER BY avg_profit_in_category DESC;

-- Win rate vs Profit correlation
SELECT 
    CASE 
        WHEN win_rate >= 0.8 THEN 'High Win Rate (≥80%)'
        WHEN win_rate >= 0.6 THEN 'Good Win Rate (60-80%)'
        WHEN win_rate >= 0.4 THEN 'Average Win Rate (40-60%)'
        ELSE 'Low Win Rate (<40%)'
    END as win_rate_category,
    COUNT(*) as pair_count,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(MIN(profit_pct), 2) as min_profit_pct,
    ROUND(MAX(profit_pct), 2) as max_profit_pct
FROM performance_rankings 
WHERE ranking_type = 'by_pair'
GROUP BY 
    CASE 
        WHEN win_rate >= 0.8 THEN 'High Win Rate (≥80%)'
        WHEN win_rate >= 0.6 THEN 'Good Win Rate (60-80%)'
        WHEN win_rate >= 0.4 THEN 'Average Win Rate (40-60%)'
        ELSE 'Low Win Rate (<40%)'
    END
ORDER BY avg_profit_pct DESC;

-- =====================================================
-- 5. MAINTENANCE QUERIES
-- =====================================================

-- Update rankings after new trades (recalculate)
-- This would typically be run by the automation system
DELETE FROM performance_rankings WHERE ranking_type = 'by_pair';

-- Re-insert with fresh data (same as population query above)
-- ... INSERT statement from section 2 ...

-- Check for data quality issues
SELECT 
    'Data Quality Check' as check_type,
    COUNT(*) as total_pairs,
    COUNT(CASE WHEN profit_pct IS NULL THEN 1 END) as null_profit_count,
    COUNT(CASE WHEN win_rate IS NULL THEN 1 END) as null_winrate_count,
    COUNT(CASE WHEN trade_count < 1 THEN 1 END) as invalid_trade_count
FROM performance_rankings 
WHERE ranking_type = 'by_pair';

-- =====================================================
-- 6. CURRENCY ANALYSIS ENHANCEMENTS
-- =====================================================

-- Base currency performance (e.g., all BTC pairs)
-- Uses base_currency field from trades table
SELECT 
    t.base_currency,
    COUNT(DISTINCT pr.entity_name) as pair_count,
    ROUND(AVG(pr.profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(pr.win_rate) * 100, 1) as avg_win_rate,
    SUM(pr.trade_count) as total_trades,
    ROUND(SUM(pr.profit_abs), 2) as total_profit
FROM performance_rankings pr
JOIN (SELECT DISTINCT pair, base_currency FROM trades) t ON pr.entity_name = t.pair
WHERE pr.ranking_type = 'by_pair'
GROUP BY t.base_currency
HAVING pair_count >= 2  -- Only base currencies with multiple pairs
ORDER BY avg_profit_pct DESC;

-- Quote currency performance (e.g., all USDT pairs)  
-- Uses quote_currency field from trades table
SELECT 
    t.quote_currency,
    COUNT(DISTINCT pr.entity_name) as pair_count,
    ROUND(AVG(pr.profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(pr.win_rate) * 100, 1) as avg_win_rate,
    SUM(pr.trade_count) as total_trades,
    ROUND(SUM(pr.total_volume), 2) as total_volume
FROM performance_rankings pr
JOIN (SELECT DISTINCT pair, quote_currency FROM trades) t ON pr.entity_name = t.pair
WHERE pr.ranking_type = 'by_pair'
GROUP BY t.quote_currency
ORDER BY total_volume DESC;

-- =====================================================
-- 7. DIRECT TRADES TABLE QUERIES
-- =====================================================

-- Quick performance check directly from trades table
-- (without needing performance_rankings table)
SELECT 
    pair,
    COUNT(*) as trade_count,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) * 100, 1) as win_rate_pct,
    ROUND(MAX(profit_pct), 2) as best_trade_pct,
    ROUND(MIN(profit_pct), 2) as worst_trade_pct,
    ROUND(SUM(stake_amount), 2) as total_volume,
    ROUND(AVG(trade_duration), 0) as avg_duration_min
FROM trades 
WHERE is_open = 0
GROUP BY pair
HAVING trade_count >= 5  -- Only pairs with meaningful trade history
ORDER BY avg_profit_pct DESC
LIMIT 20;