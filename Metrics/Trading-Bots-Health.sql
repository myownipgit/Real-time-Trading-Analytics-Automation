--- Bot's Health ---

SELECT metric_name,
       ROUND(metric_value, 2) as value,
       metric_unit,
       health_status
FROM bot_health_metrics
ORDER BY metric_name