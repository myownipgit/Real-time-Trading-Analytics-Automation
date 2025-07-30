--- Top Performing Pairs ---

SELECT entity_name as pair, ROUND(profit_pct, 2) as avg_profit_pct, ROUND(win_rate * 100, 1) as win_rate_pct, trade_count FROM performance_rankings ORDER BY profit_pct DESC LIMIT 10