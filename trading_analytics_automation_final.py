#!/usr/bin/env python3
"""
Real-time Trading Analytics Automation System
Automatically updates your 8 analytics categories when trades complete
"""

import sqlite3
import time
import logging
from datetime import datetime
import schedule
import os

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('trading_analytics.log'),
        logging.StreamHandler()
    ]
)

class TradingAnalyticsAutomator:
    def __init__(self, analytics_db_path=None):
        # Use MCP database path if no specific path provided
        if analytics_db_path is None:
            analytics_db_path = os.path.expanduser('~/db_dev/trading_test.db')
        
        self.analytics_db = analytics_db_path
        self.last_processed_trade_id = self.get_last_processed_trade_id()
        
        logging.info(f"Initialized TradingAnalyticsAutomator with database: {self.analytics_db}")
        logging.info(f"Last processed trade ID: {self.last_processed_trade_id}")
        
    def get_last_processed_trade_id(self):
        """Get the ID of the last processed trade from analysis_snapshots"""
        try:
            with sqlite3.connect(self.analytics_db) as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT MAX(last_trade_id) FROM analysis_snapshots WHERE status = 'completed'")
                result = cursor.fetchone()
                if result and result[0]:
                    return result[0]
                else:
                    # If no snapshots exist, start from 0 to process all trades
                    return 0
        except Exception as e:
            logging.warning(f"Could not get last processed trade ID: {e}")
            return 0
    
    def check_for_new_trades(self):
        """Check if there are new completed trades to process"""
        try:
            with sqlite3.connect(self.analytics_db) as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT COUNT(*) FROM trades 
                    WHERE trade_id > ? AND is_open = 0
                """, (self.last_processed_trade_id,))
                
                count = cursor.fetchone()[0]
                
                if count > 0:
                    logging.info(f"Found {count} new completed trades")
                    self.process_new_trades(count)
                    return True
                return False
                
        except Exception as e:
            logging.error(f"Error checking for new trades: {e}")
            return False
    
    def process_new_trades(self, trade_count):
        """Process new trades and update all analytics"""
        try:
            with sqlite3.connect(self.analytics_db) as conn:
                # Get the maximum trade_id to update our tracking
                cursor = conn.cursor()
                cursor.execute("SELECT MAX(trade_id) FROM trades WHERE is_open = 0")
                max_trade_id = cursor.fetchone()[0]
                
                # Start analysis snapshot
                cursor.execute("""
                    INSERT INTO analysis_snapshots (
                        snapshot_type, records_processed, status, last_trade_id
                    ) VALUES (?, ?, ?, ?)
                """, ('automated_analysis', trade_count, 'processing', max_trade_id))
                
                snapshot_id = cursor.lastrowid
                
                try:
                    # Update all 8 analytics categories
                    self.update_performance_rankings(conn)
                    self.update_risk_metrics(conn)
                    self.update_strategy_performance(conn)
                    self.update_timing_analysis(conn)
                    self.update_pair_analytics(conn)
                    self.update_stop_loss_analytics(conn)
                    self.update_duration_patterns(conn)
                    self.update_bot_health_metrics(conn)
                    
                    # Update last processed ID
                    self.last_processed_trade_id = max_trade_id
                    
                    # Mark snapshot as completed
                    cursor.execute("""
                        UPDATE analysis_snapshots 
                        SET status = 'completed', last_trade_id = ?
                        WHERE id = ?
                    """, (self.last_processed_trade_id, snapshot_id))
                    
                    conn.commit()
                    logging.info(f"Successfully processed {trade_count} trades")
                    
                except Exception as e:
                    # Mark snapshot as failed
                    cursor.execute("""
                        UPDATE analysis_snapshots 
                        SET status = 'failed', error_message = ?
                        WHERE id = ?
                    """, (str(e), snapshot_id))
                    conn.commit()
                    raise
                    
        except Exception as e:
            logging.error(f"Error processing new trades: {e}")
    
    def update_performance_rankings(self, conn):
        """Update performance rankings for all pairs"""
        # Clear existing rankings and recalculate
        conn.execute("DELETE FROM performance_rankings WHERE ranking_type = 'by_pair'")
        
        conn.execute("""
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
        """)
        logging.info("Updated performance rankings")
    
    def update_risk_metrics(self, conn):
        """Update risk management metrics"""
        # Clear existing metrics and recalculate
        conn.execute("DELETE FROM risk_metrics WHERE metric_type = 'overall'")
        
        conn.execute("""
            INSERT INTO risk_metrics (
                metric_type, stop_loss_triggered_count, 
                stop_loss_effectiveness_pct, sharpe_ratio,
                max_drawdown_pct, analysis_date
            )
            SELECT 
                'overall' as metric_type,
                SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as sl_triggered,
                CASE 
                    WHEN SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) > 0 
                    THEN (SUM(CASE WHEN exit_reason = 'stop_loss' AND profit_abs < 0 THEN ABS(profit_abs) ELSE 0 END) / 
                          NULLIF(SUM(CASE WHEN profit_abs < 0 THEN ABS(profit_abs) ELSE 0 END), 0) * 100)
                    ELSE 0 
                END as sl_effectiveness,
                0.0 as sharpe_ratio,  -- Simplified for now
                MIN(profit_pct) as max_drawdown_pct,
                CURRENT_TIMESTAMP as analysis_date
            FROM trades WHERE is_open = 0
        """)
        logging.info("Updated risk metrics")
    
    def update_strategy_performance(self, conn):
        """Update strategy comparison metrics"""
        # Clear existing data and recalculate
        conn.execute("DELETE FROM strategy_performance")
        
        conn.execute("""
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
                0.5 as consistency_score,  -- Simplified calculation
                AVG(trade_duration) as avg_trade_duration_minutes,
                CURRENT_TIMESTAMP as analysis_date
            FROM trades 
            WHERE is_open = 0 
            GROUP BY strategy
        """)
        logging.info("Updated strategy performance")
    
    def update_timing_analysis(self, conn):
        """Update timing analysis with the actual table structure"""
        # Clear existing data and recalculate
        conn.execute("DELETE FROM timing_analysis")
        
        # Get hourly performance data
        cursor = conn.cursor()
        cursor.execute("""
            SELECT 
                strftime('%H', open_date) as hour,
                COUNT(*) as trade_count,
                AVG(profit_pct) as avg_profit_pct,
                AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
                AVG(trade_duration) as avg_duration
            FROM trades 
            WHERE is_open = 0 AND open_date IS NOT NULL
            GROUP BY strftime('%H', open_date)
            ORDER BY avg_profit_pct DESC
        """)
        
        hourly_data = cursor.fetchall()
        if hourly_data:
            best_hour = int(hourly_data[0][0]) if hourly_data[0][0] else 0
            worst_hour = int(hourly_data[-1][0]) if hourly_data[-1][0] else 0
            
            # Calculate weekend vs weekday performance
            cursor.execute("""
                SELECT 
                    CASE WHEN strftime('%w', open_date) IN ('0', '6') THEN 'weekend' ELSE 'weekday' END as period_type,
                    AVG(profit_pct) as avg_profit_pct
                FROM trades 
                WHERE is_open = 0 AND open_date IS NOT NULL
                GROUP BY CASE WHEN strftime('%w', open_date) IN ('0', '6') THEN 'weekend' ELSE 'weekday' END
            """)
            
            period_data = cursor.fetchall()
            weekend_perf = next((row[1] for row in period_data if row[0] == 'weekend'), 0.0)
            weekday_perf = next((row[1] for row in period_data if row[0] == 'weekday'), 0.0)
        else:
            best_hour = worst_hour = 0
            weekend_perf = weekday_perf = 0.0
        
        # Insert the timing analysis
        conn.execute("""
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
                ? as best_performance_hour,
                ? as worst_performance_hour,
                ? as weekend_performance_pct,
                ? as weekday_performance_pct,
                AVG(trade_duration) as duration_minutes_avg,
                CURRENT_TIMESTAMP as analysis_date
            FROM trades 
            WHERE is_open = 0
        """, (best_hour, worst_hour, weekend_perf, weekday_perf))
        
        logging.info("Updated timing analysis")
    
    def update_pair_analytics(self, conn):
        """Update individual pair analytics"""
        # Clear existing data and recalculate
        conn.execute("DELETE FROM pair_analytics")
        
        conn.execute("""
            INSERT INTO pair_analytics (
                pair, base_currency, quote_currency, total_trades, 
                winning_trades, losing_trades, win_rate, avg_profit_pct,
                total_profit_abs, avg_trade_duration_minutes, price_volatility_pct,
                analysis_date
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
                CURRENT_TIMESTAMP as analysis_date
            FROM trades 
            WHERE is_open = 0 
            GROUP BY pair, base_currency, quote_currency
        """)
        logging.info("Updated pair analytics")
    
    def update_stop_loss_analytics(self, conn):
        """Update stop loss effectiveness analysis"""
        # Clear existing data and recalculate
        conn.execute("DELETE FROM stop_loss_analytics")
        
        conn.execute("""
            INSERT INTO stop_loss_analytics (
                analysis_type, pair, stop_loss_level_pct, total_trades_with_sl,
                sl_triggered_count, sl_effectiveness_pct, 
                avg_loss_when_triggered_pct, avg_profit_when_not_triggered_pct,
                analysis_date
            )
            SELECT 
                'by_pair' as analysis_type,
                pair,
                AVG(stop_loss_pct) as stop_loss_level_pct,
                COUNT(*) as total_trades_with_sl,
                SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as sl_triggered_count,
                CASE 
                    WHEN SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) > 0
                    THEN (SUM(CASE WHEN exit_reason = 'stop_loss' AND profit_pct > -10 THEN 1 ELSE 0 END) * 1.0 / 
                          SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END)) * 100
                    ELSE 0
                END as sl_effectiveness_pct,
                AVG(CASE WHEN exit_reason = 'stop_loss' THEN profit_pct ELSE NULL END) as avg_loss_when_triggered_pct,
                AVG(CASE WHEN exit_reason != 'stop_loss' THEN profit_pct ELSE NULL END) as avg_profit_when_not_triggered_pct,
                CURRENT_TIMESTAMP as analysis_date
            FROM trades 
            WHERE is_open = 0 AND stop_loss_pct IS NOT NULL
            GROUP BY pair
        """)
        logging.info("Updated stop loss analytics")
    
    def update_duration_patterns(self, conn):
        """Update trade duration pattern analysis"""
        # Clear existing data and recalculate
        conn.execute("DELETE FROM duration_patterns")
        
        conn.execute("""
            INSERT INTO duration_patterns (
                pattern_type, duration_category, min_duration_minutes, 
                max_duration_minutes, trade_count, win_rate, avg_profit_pct,
                total_profit_abs, optimal_exit_timing_minutes, analysis_date
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
        """)
        logging.info("Updated duration patterns")
    
    def update_bot_health_metrics(self, conn):
        """Update overall bot health metrics"""
        # Clear existing metrics
        conn.execute("DELETE FROM bot_health_metrics")
        
        # Calculate current health metrics
        cursor = conn.cursor()
        
        # Get overall stats
        cursor.execute("""
            SELECT 
                COUNT(*) as total_trades,
                AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
                AVG(profit_pct) as avg_profit_pct,
                SUM(profit_abs) as total_profit,
                MIN(profit_pct) as worst_loss,
                MAX(profit_pct) as best_win
            FROM trades WHERE is_open = 0
        """)
        stats = cursor.fetchone()
        
        if stats and stats[0] > 0:
            total_trades, win_rate, avg_profit_pct, total_profit, worst_loss, best_win = stats
            
            # Determine health status
            if win_rate >= 0.7 and avg_profit_pct >= 0.5:
                status = "HEALTHY"
            elif win_rate >= 0.5 and avg_profit_pct >= 0:
                status = "WARNING" 
            else:
                status = "CRITICAL"
            
            # Insert multiple health metrics
            health_metrics = [
                ('overall_win_rate', win_rate * 100, '%', status, 60.0, 40.0),
                ('avg_profit_pct', avg_profit_pct, '%', status, 0.5, 0.0),
                ('total_trades', total_trades, 'count', 'HEALTHY', None, None),
                ('total_profit', total_profit, 'abs', status, None, None),
                ('worst_loss', worst_loss, '%', 'HEALTHY' if worst_loss > -20 else 'WARNING', -10.0, -20.0),
                ('best_win', best_win, '%', 'HEALTHY', None, None)
            ]
            
            for metric_name, metric_value, unit, health_status, threshold_warning, threshold_critical in health_metrics:
                conn.execute("""
                    INSERT INTO bot_health_metrics (
                        metric_name, metric_value, metric_unit, health_status, 
                        threshold_warning, threshold_critical,
                        last_calculation, analysis_date
                    ) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """, (metric_name, metric_value, unit, health_status, 
                      threshold_warning, threshold_critical))
            
        logging.info("Updated bot health metrics")
    
    def run_scheduled_analysis(self):
        """Run the complete analysis cycle"""
        logging.info("Starting scheduled analysis cycle...")
        
        if self.check_for_new_trades():
            logging.info("Analysis completed - new trades processed")
        else:
            logging.info("Analysis completed - no new trades")
    
    def start_automation(self):
        """Start the automation system"""
        logging.info("Starting Trading Analytics Automation System")
        
        # Schedule checks every 5 minutes
        schedule.every(5).minutes.do(self.run_scheduled_analysis)
        
        # Schedule full health check every hour
        schedule.every().hour.do(self.run_scheduled_analysis)
        
        logging.info("Automation scheduled - checking every 5 minutes")
        
        try:
            while True:
                schedule.run_pending()
                time.sleep(30)  # Check every 30 seconds for scheduled jobs
                
        except KeyboardInterrupt:
            logging.info("Automation stopped by user")
        except Exception as e:
            logging.error(f"Automation error: {e}")

def main():
    """Main entry point"""
    logging.info("=== Trading Analytics Automation System Starting ===")
    
    # Initialize the automator
    automator = TradingAnalyticsAutomator()
    
    # Run initial analysis
    automator.run_scheduled_analysis()
    
    # Start continuous automation
    automator.start_automation()

if __name__ == "__main__":
    main()