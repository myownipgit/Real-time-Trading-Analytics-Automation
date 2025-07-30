--- Best Trading Hours ---

SELECT best_performance_hour as best_hour,
       worst_performance_hour as worst_hour,
       ROUND(weekend_performance_pct, 2) as weekend_profit,
       ROUND(weekday_performance_pct, 2) as weekday_profit
FROM timing_analysis