-- Strategy Performance SQL
-- Purpose: Compares different trading strategies
-- Data Source: ~/db_dev/trading_test.db trades table
-- Key Metrics: Win rates, profit factors, expectancy, consistency scores

-- =====================================================
-- 1. CREATE TABLE: strategy_performance
-- =====================================================

CREATE TABLE IF NOT EXISTS strategy_performance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    strategy_name TEXT NOT NULL,            -- Name of the trading strategy
    total_trades INTEGER,                   -- Total number of trades
    winning_trades INTEGER,                 -- Number of profitable trades
    losing_trades INTEGER,                  -- Number of losing trades
    win_rate REAL,                         -- Win rate (0.0 to 1.0)
    avg_profit_pct REAL,                   -- Average profit percentage
    total_profit_abs REAL,                 -- Total absolute profit
    profit_factor REAL,                    -- Gross profit / Gross loss
    expectancy REAL,                       -- Expected value per trade
    best_trade_pct REAL,                   -- Best single trade percentage
    worst_trade_pct REAL,                  -- Worst single trade percentage
    consistency_score REAL,                -- Strategy consistency metric
    avg_trade_duration_minutes REAL,       -- Average trade duration
    max_consecutive_wins INTEGER,          -- Longest winning streak
    max_consecutive_losses INTEGER,        -- Longest losing streak
    sharpe_ratio REAL,                     -- Risk-adjusted return
    sortino_ratio REAL,                    -- Downside risk-adjusted return
    calmar_ratio REAL,                     -- Return vs max drawdown
    analysis_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for performance
    UNIQUE(strategy_name)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_strategy_performance_name ON strategy_performance(strategy_name);
CREATE INDEX IF NOT EXISTS idx_strategy_performance_profit ON strategy_performance(avg_profit_pct DESC);
CREATE INDEX IF NOT EXISTS idx_strategy_performance_winrate ON strategy_performance(win_rate DESC);

-- =====================================================
-- 2. POPULATE TABLE: Core Strategy Metrics
-- =====================================================

-- Clear existing data and recalculate
DELETE FROM strategy_performance;

-- Insert core strategy performance metrics
-- Based on actual implementation from trading_analytics_automation_final.py
INSERT INTO strategy_performance (
    strategy_name, total_trades, winning_trades, losing_trades,
    win_rate, avg_profit_pct, total_profit_abs, profit_factor,
    expectancy, best_trade_pct, worst_trade_pct, 
    consistency_score, avg_trade_duration_minutes, analysis_date
)
SELECT 
    strategy as strategy_name,
    COUNT(*) as total_trades,
    SUM(CASE WHEN profit_pct > 0 THEN 1 ELSE 0 END) as winning_trades,
    SUM(CASE WHEN profit_pct <= 0 THEN 1 ELSE 0 END) as losing_trades,
    AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
    AVG(profit_pct) as avg_profit_pct,
    SUM(profit_abs) as total_profit_abs,
    CASE 
        WHEN SUM(CASE WHEN profit_abs < 0 THEN ABS(profit_abs) ELSE 0 END) > 0
        THEN SUM(CASE WHEN profit_abs > 0 THEN profit_abs ELSE 0 END) / 
             SUM(CASE WHEN profit_abs < 0 THEN ABS(profit_abs) ELSE 0 END)
        ELSE 0
    END as profit_factor,
    AVG(profit_pct) * AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as expectancy,
    MAX(profit_pct) as best_trade_pct,
    MIN(profit_pct) as worst_trade_pct,
    0.5 as consistency_score,  -- Simplified calculation (matches automation code)
    AVG(trade_duration) as avg_trade_duration_minutes,
    CURRENT_TIMESTAMP as analysis_date
FROM trades 
WHERE is_open = 0 
GROUP BY strategy
HAVING COUNT(*) >= 1;  -- Include all strategies with at least 1 trade

-- =====================================================
-- 3. UPDATE TABLE: Advanced Strategy Metrics
-- =====================================================

-- Calculate consecutive wins/losses for each strategy
UPDATE strategy_performance SET
    max_consecutive_wins = (
        SELECT MAX(consecutive_count) 
        FROM (
            SELECT strategy, COUNT(*) as consecutive_count
            FROM (
                SELECT strategy, profit_pct,
                       ROW_NUMBER() OVER (PARTITION BY strategy ORDER BY trade_id) - 
                       ROW_NUMBER() OVER (PARTITION BY strategy, CASE WHEN profit_pct > 0 THEN 1 ELSE 0 END ORDER BY trade_id) as grp
                FROM trades 
                WHERE is_open = 0 AND strategy = strategy_performance.strategy_name
            ) grouped
            WHERE profit_pct > 0
            GROUP BY strategy, grp
        ) wins_streaks
    ),
    max_consecutive_losses = (
        SELECT MAX(consecutive_count) 
        FROM (
            SELECT strategy, COUNT(*) as consecutive_count
            FROM (
                SELECT strategy, profit_pct,
                       ROW_NUMBER() OVER (PARTITION BY strategy ORDER BY trade_id) - 
                       ROW_NUMBER() OVER (PARTITION BY strategy, CASE WHEN profit_pct <= 0 THEN 1 ELSE 0 END ORDER BY trade_id) as grp
                FROM trades 
                WHERE is_open = 0 AND strategy = strategy_performance.strategy_name
            ) grouped
            WHERE profit_pct <= 0
            GROUP BY strategy, grp
        ) loss_streaks
    );

-- Calculate improved consistency score based on profit stability
UPDATE strategy_performance SET
    consistency_score = (
        SELECT 
            CASE 
                WHEN AVG(profit_pct) = 0 THEN 0
                ELSE 1.0 - (SQRT(AVG(profit_pct * profit_pct) - AVG(profit_pct) * AVG(profit_pct)) / ABS(AVG(profit_pct)))
            END
        FROM trades 
        WHERE is_open = 0 AND strategy = strategy_performance.strategy_name
        HAVING COUNT(*) > 1
    )
WHERE total_trades > 1;

-- Calculate Sharpe ratio (simplified - assumes risk-free rate of 0)
UPDATE strategy_performance SET
    sharpe_ratio = (
        SELECT 
            CASE 
                WHEN SQRT(AVG(profit_pct * profit_pct) - AVG(profit_pct) * AVG(profit_pct)) > 0
                THEN AVG(profit_pct) / SQRT(AVG(profit_pct * profit_pct) - AVG(profit_pct) * AVG(profit_pct))
                ELSE 0
            END
        FROM trades 
        WHERE is_open = 0 AND strategy = strategy_performance.strategy_name
        HAVING COUNT(*) > 1
    )
WHERE total_trades > 1;

-- Calculate Sortino ratio (downside deviation only)
UPDATE strategy_performance SET
    sortino_ratio = (
        SELECT 
            CASE 
                WHEN SQRT(AVG(CASE WHEN profit_pct < 0 THEN profit_pct * profit_pct ELSE 0 END)) > 0
                THEN AVG(profit_pct) / SQRT(AVG(CASE WHEN profit_pct < 0 THEN profit_pct * profit_pct ELSE 0 END))
                ELSE 0
            END
        FROM trades 
        WHERE is_open = 0 AND strategy = strategy_performance.strategy_name
        HAVING COUNT(*) > 1
    )
WHERE total_trades > 1;

-- Calculate Calmar ratio (return vs max drawdown)
UPDATE strategy_performance SET
    calmar_ratio = (
        SELECT 
            CASE 
                WHEN MIN(profit_pct) < 0
                THEN AVG(profit_pct) / ABS(MIN(profit_pct))
                ELSE 0
            END
        FROM trades 
        WHERE is_open = 0 AND strategy = strategy_performance.strategy_name
    )
WHERE total_trades > 1;

-- =====================================================
-- 4. QUERY EXAMPLES: Strategy Performance Analysis
-- =====================================================

-- Overall strategy ranking by profitability
SELECT 
    strategy_name,
    total_trades,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(total_profit_abs, 2) as total_profit,
    ROUND(profit_factor, 2) as profit_factor,
    ROUND(expectancy, 3) as expectancy
FROM strategy_performance 
ORDER BY avg_profit_pct DESC;

-- Best performing strategies (comprehensive view)
SELECT 
    strategy_name,
    total_trades,
    ROUND(win_rate * 100, 1) as win_rate_pct,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(profit_factor, 2) as profit_factor,
    ROUND(best_trade_pct, 2) as best_trade_pct,
    ROUND(worst_trade_pct, 2) as worst_trade_pct,
    ROUND(consistency_score, 3) as consistency,
    ROUND(avg_trade_duration_minutes, 0) as avg_duration_min
FROM strategy_performance 
WHERE total_trades >= 5  -- Only strategies with meaningful history
ORDER BY avg_profit_pct DESC
LIMIT 10;

-- Risk-adjusted strategy ranking
SELECT 
    strategy_name,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(sharpe_ratio, 3) as sharpe_ratio,
    ROUND(sortino_ratio, 3) as sortino_ratio,
    ROUND(calmar_ratio, 3) as calmar_ratio,
    max_consecutive_losses,
    ROUND(consistency_score, 3) as consistency
FROM strategy_performance 
WHERE total_trades >= 10
ORDER BY sharpe_ratio DESC;

-- Strategy efficiency analysis
SELECT 
    strategy_name,
    total_trades,
    ROUND(avg_profit_pct, 2) as avg_profit_pct,
    ROUND(avg_trade_duration_minutes, 0) as avg_duration_min,
    ROUND(avg_profit_pct / (avg_trade_duration_minutes / 60.0), 3) as profit_per_hour,
    ROUND(total_profit_abs / total_trades, 2) as profit_per_trade
FROM strategy_performance 
WHERE avg_trade_duration_minutes > 0
ORDER BY profit_per_hour DESC;

-- =====================================================
-- 5. ANALYTICS QUERIES: Strategy Insights
-- =====================================================

-- Strategy performance distribution
SELECT 
    CASE 
        WHEN avg_profit_pct >= 2.0 THEN 'Excellent (≥2%)'
        WHEN avg_profit_pct >= 1.0 THEN 'Good (1-2%)'
        WHEN avg_profit_pct >= 0.0 THEN 'Break-even (0-1%)'
        ELSE 'Losing (<0%)'
    END as performance_category,
    COUNT(*) as strategy_count,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_in_category,
    ROUND(AVG(win_rate) * 100, 1) as avg_win_rate_pct,
    SUM(total_trades) as total_trades_in_category
FROM strategy_performance 
GROUP BY 
    CASE 
        WHEN avg_profit_pct >= 2.0 THEN 'Excellent (≥2%)'
        WHEN avg_profit_pct >= 1.0 THEN 'Good (1-2%)'
        WHEN avg_profit_pct >= 0.0 THEN 'Break-even (0-1%)'
        ELSE 'Losing (<0%)'
    END
ORDER BY avg_profit_in_category DESC;

-- Win rate vs Profit analysis
SELECT 
    CASE 
        WHEN win_rate >= 0.8 THEN 'High Win Rate (≥80%)'
        WHEN win_rate >= 0.6 THEN 'Good Win Rate (60-80%)'
        WHEN win_rate >= 0.4 THEN 'Average Win Rate (40-60%)'
        ELSE 'Low Win Rate (<40%)'
    END as win_rate_category,
    COUNT(*) as strategy_count,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(profit_factor), 2) as avg_profit_factor,
    ROUND(AVG(expectancy), 3) as avg_expectancy
FROM strategy_performance 
GROUP BY 
    CASE 
        WHEN win_rate >= 0.8 THEN 'High Win Rate (≥80%)'
        WHEN win_rate >= 0.6 THEN 'Good Win Rate (60-80%)'
        WHEN win_rate >= 0.4 THEN 'Average Win Rate (40-60%)'
        ELSE 'Low Win Rate (<40%)'
    END
ORDER BY avg_profit_pct DESC;

-- Strategy consistency analysis
SELECT 
    CASE 
        WHEN consistency_score >= 0.8 THEN 'Very Consistent (≥80%)'
        WHEN consistency_score >= 0.6 THEN 'Consistent (60-80%)'
        WHEN consistency_score >= 0.4 THEN 'Moderately Consistent (40-60%)'
        ELSE 'Inconsistent (<40%)'
    END as consistency_category,
    COUNT(*) as strategy_count,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(consistency_score), 3) as avg_consistency,
    ROUND(AVG(max_consecutive_losses), 1) as avg_max_loss_streak
FROM strategy_performance 
WHERE consistency_score IS NOT NULL
GROUP BY 
    CASE 
        WHEN consistency_score >= 0.8 THEN 'Very Consistent (≥80%)'
        WHEN consistency_score >= 0.6 THEN 'Consistent (60-80%)'
        WHEN consistency_score >= 0.4 THEN 'Moderately Consistent (40-60%)'
        ELSE 'Inconsistent (<40%)'
    END
ORDER BY avg_profit_pct DESC;

-- Trade duration vs Performance
SELECT 
    CASE 
        WHEN avg_trade_duration_minutes <= 60 THEN 'Scalp (≤1h)'
        WHEN avg_trade_duration_minutes <= 480 THEN 'Short (1-8h)'
        WHEN avg_trade_duration_minutes <= 1440 THEN 'Day (8-24h)'
        ELSE 'Swing (>24h)'
    END as duration_category,
    COUNT(*) as strategy_count,
    ROUND(AVG(avg_profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(win_rate) * 100, 1) as avg_win_rate_pct,
    ROUND(AVG(avg_trade_duration_minutes), 0) as avg_duration_min
FROM strategy_performance 
WHERE avg_trade_duration_minutes IS NOT NULL
GROUP BY 
    CASE 
        WHEN avg_trade_duration_minutes <= 60 THEN 'Scalp (≤1h)'
        WHEN avg_trade_duration_minutes <= 480 THEN 'Short (1-8h)'
        WHEN avg_trade_duration_minutes <= 1440 THEN 'Day (8-24h)'
        ELSE 'Swing (>24h)'
    END
ORDER BY avg_profit_pct DESC;

-- =====================================================
-- 6. STRATEGY COMPARISON QUERIES
-- =====================================================

-- Head-to-head strategy comparison (top 2 strategies)
WITH top_strategies AS (
    SELECT strategy_name, avg_profit_pct
    FROM strategy_performance
    ORDER BY avg_profit_pct DESC
    LIMIT 2
)
SELECT 
    'Strategy Comparison' as analysis_type,
    (SELECT strategy_name FROM top_strategies LIMIT 1) as best_strategy,
    (SELECT ROUND(avg_profit_pct, 2) FROM top_strategies LIMIT 1) as best_profit_pct,
    (SELECT strategy_name FROM top_strategies LIMIT 1 OFFSET 1) as second_strategy,
    (SELECT ROUND(avg_profit_pct, 2) FROM top_strategies LIMIT 1 OFFSET 1) as second_profit_pct,
    ROUND((SELECT avg_profit_pct FROM top_strategies LIMIT 1) - 
          (SELECT avg_profit_pct FROM top_strategies LIMIT 1 OFFSET 1), 2) as profit_difference;

-- Strategy performance matrix
SELECT 
    sp.strategy_name,
    sp.total_trades,
    ROUND(sp.avg_profit_pct, 2) as profit_pct,
    ROUND(sp.win_rate * 100, 1) as win_rate_pct,
    ROUND(sp.profit_factor, 2) as profit_factor,
    ROUND(sp.sharpe_ratio, 3) as sharpe,
    sp.max_consecutive_losses as max_loss_streak,
    CASE 
        WHEN sp.avg_profit_pct >= 1.5 AND sp.win_rate >= 0.7 THEN 'Star Performer'
        WHEN sp.avg_profit_pct >= 1.0 AND sp.win_rate >= 0.6 THEN 'Solid Performer'
        WHEN sp.avg_profit_pct >= 0.5 THEN 'Moderate Performer'
        WHEN sp.avg_profit_pct >= 0.0 THEN 'Break-even'
        ELSE 'Underperformer'
    END as performance_rating
FROM strategy_performance sp
WHERE sp.total_trades >= 5
ORDER BY sp.avg_profit_pct DESC;

-- =====================================================
-- 7. DIRECT TRADES TABLE STRATEGY ANALYSIS  
-- =====================================================

-- Quick strategy analysis directly from trades table
SELECT 
    strategy,
    COUNT(*) as total_trades,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) * 100, 1) as win_rate_pct,
    ROUND(MAX(profit_pct), 2) as best_trade_pct,
    ROUND(MIN(profit_pct), 2) as worst_trade_pct,
    ROUND(SUM(profit_abs), 2) as total_profit,
    COUNT(DISTINCT pair) as pairs_traded,
    ROUND(AVG(trade_duration), 0) as avg_duration_min
FROM trades 
WHERE is_open = 0 AND strategy IS NOT NULL
GROUP BY strategy
HAVING total_trades >= 3
ORDER BY avg_profit_pct DESC;

-- Strategy performance by pair (which strategies work best on which pairs)
SELECT 
    strategy,
    pair,
    COUNT(*) as trades,
    ROUND(AVG(profit_pct), 2) as avg_profit_pct,
    ROUND(AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) * 100, 1) as win_rate_pct
FROM trades 
WHERE is_open = 0 AND strategy IS NOT NULL
GROUP BY strategy, pair
HAVING trades >= 2
ORDER BY strategy, avg_profit_pct DESC;

-- =====================================================
-- 8. MAINTENANCE QUERIES
-- =====================================================

-- Recalculate all strategy performance metrics
DELETE FROM strategy_performance;

-- Re-run INSERT and UPDATE statements from sections 2 and 3
-- ... (Would typically be executed by automation system)

-- Data quality check for strategy performance
SELECT 
    'Strategy Performance Quality Check' as check_type,
    COUNT(*) as total_strategies,
    COUNT(CASE WHEN avg_profit_pct IS NULL THEN 1 END) as null_profit_count,
    COUNT(CASE WHEN win_rate IS NULL THEN 1 END) as null_winrate_count,
    COUNT(CASE WHEN total_trades < 1 THEN 1 END) as invalid_trade_count,
    COUNT(CASE WHEN win_rate > 1.0 THEN 1 END) as invalid_winrate_count
FROM strategy_performance;