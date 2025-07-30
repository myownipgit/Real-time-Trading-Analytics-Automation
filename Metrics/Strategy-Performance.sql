--- Strategy Performance --

SELECT strategy_name,
       ROUND(win_rate * 100, 1) as win_rate_pct,
       ROUND(avg_profit_pct, 2) as avg_profit,
       total_trades
FROM strategy_performance 
ORDER BY avg_profit_pct DESC
