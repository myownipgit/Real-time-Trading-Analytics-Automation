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
                    SELECT * FROM trades 
                    WHERE trade_id > ? AND is_open = 0 
                    ORDER BY trade_id
                """, (self.last_processed_trade_id,))
                
                new_trades = cursor.fetchall()
                
                if new_trades:
                    logging.info(f"Found {len(new_trades)} new completed trades")
                    self.process_new_trades(new_trades)
                    return True
                return False
                
        except Exception as e:
            logging.error(f"Error checking for new trades: {e}")
            return False
    
    def process_new_trades(self, new_trades):
        """Process new trades and update all analytics"""
        try:
            with sqlite3.connect(self.analytics_db) as conn:
                # Start analysis snapshot
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO analysis_snapshots (
                        snapshot_type, records_processed, status, last_trade_id
                    ) VALUES (?, ?, ?, ?)
                """, ('automated_analysis', len(new_trades), 'processing', 
                      max([trade[0] for trade in new_trades])))  # trade[0] is trade_id
                
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
                    self.last_processed_trade_id = max([trade[0] for trade in new_trades])
                    
                    # Mark snapshot as completed
                    cursor.execute("""
                        UPDATE analysis_snapshots 
                        SET status = 'completed', last_trade_id = ?
                        WHERE id = ?
                    """, (self.last_processed_trade_id, snapshot_id))
                    
                    conn.commit()
                    logging.info(f"Successfully processed {len(new_trades)} trades")
                    
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
        conn.execute("""
            INSERT OR REPLACE INTO performance_rankings (
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
        # Overall risk metrics
        conn.execute("""
            INSERT OR REPLACE INTO risk_metrics (
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
                CASE 
                    WHEN AVG(profit_pct) != 0 AND (
                        SELECT COUNT(*) FROM (
                            SELECT profit_pct FROM trades WHERE is_open = 0
                        ) 
                    ) > 1
                    THEN AVG(profit_pct) / NULLIF(
                        SQRT(AVG(profit_pct * profit_pct) - AVG(profit_pct) * AVG(profit_pct)), 0
                    )
                    ELSE 0
                END as sharpe_ratio,
                (SELECT MIN(running_total) FROM (
                    SELECT SUM(profit_abs) OVER (ORDER BY close_date) as running_total
                    FROM trades WHERE is_open = 0 AND close_date IS NOT NULL
                )) as max_drawdown_pct,
                CURRENT_TIMESTAMP as analysis_date
            FROM trades WHERE is_open = 0
        """)
        logging.info("Updated risk metrics")
    
    def update_strategy_performance(self, conn):
        """Update strategy comparison metrics"""
        conn.execute("""
            INSERT OR REPLACE INTO strategy_performance (
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
                CASE 
                    WHEN AVG(ABS(profit_pct)) > 0
                    THEN 1.0 - (
                        SQRT(AVG(profit_pct * profit_pct) - AVG(profit_pct) * AVG(profit_pct)) / 
                        AVG(ABS(profit_pct))
                    )
                    ELSE 0
                END as consistency_score,
                AVG(trade_duration) as avg_trade_duration_minutes,
                CURRENT_TIMESTAMP as analysis_date
            FROM trades 
            WHERE is_open = 0 
            GROUP BY strategy
        """)
        logging.info("Updated strategy performance")
    
    def update_timing_analysis(self, conn):
        """Update timing analysis (hour of day, day of week)"""
        # Hour of day analysis
        conn.execute("""
            INSERT OR REPLACE INTO timing_analysis (
                time_category, time_value, trade_count, avg_profit_pct,
                win_rate, last_updated
            )
            SELECT 
                'hour_of_day' as time_category,
                strftime('%H', open_date) as time_value,
                COUNT(*) as trade_count,
                AVG(profit_pct) as avg_profit_pct,
                AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
                CURRENT_TIMESTAMP as last_updated
            FROM trades 
            WHERE is_open = 0 AND open_date IS NOT NULL
            GROUP BY strftime('%H', open_date)
        """)
        
        # Day of week analysis
        conn.execute("""
            INSERT OR REPLACE INTO timing_analysis (
                time_category, time_value, trade_count, avg_profit_pct,
                win_rate, last_updated
            )
            SELECT 
                'day_of_week' as time_category,
                CASE strftime('%w', open_date)
                    WHEN '0' THEN 'Sunday'
                    WHEN '1' THEN 'Monday'
                    WHEN '2' THEN 'Tuesday'
                    WHEN '3' THEN 'Wednesday'
                    WHEN '4' THEN 'Thursday'
                    WHEN '5' THEN 'Friday'
                    WHEN '6' THEN 'Saturday'
                END as time_value,
                COUNT(*) as trade_count,
                AVG(profit_pct) as avg_profit_pct,
                AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
                CURRENT_TIMESTAMP as last_updated
            FROM trades 
            WHERE is_open = 0 AND open_date IS NOT NULL
            GROUP BY strftime('%w', open_date)
        """)
        logging.info("Updated timing analysis")
    
    def update_pair_analytics(self, conn):
        """Update individual pair analytics"""
        conn.execute("""
            INSERT OR REPLACE INTO pair_analytics (
                pair, trade_count, total_profit_abs, avg_profit_pct,
                win_rate, avg_duration_minutes, volatility_score, last_updated
            )
            SELECT 
                pair,
                COUNT(*) as trade_count,
                SUM(profit_abs) as total_profit_abs,
                AVG(profit_pct) as avg_profit_pct,
                AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
                AVG(trade_duration) as avg_duration_minutes,
                CASE 
                    WHEN COUNT(*) > 1
                    THEN SQRT(AVG(profit_pct * profit_pct) - AVG(profit_pct) * AVG(profit_pct))
                    ELSE 0
                END as volatility_score,
                CURRENT_TIMESTAMP as last_updated
            FROM trades 
            WHERE is_open = 0 
            GROUP BY pair
        """)
        logging.info("Updated pair analytics")
    
    def update_stop_loss_analytics(self, conn):
        """Update stop loss effectiveness analysis"""
        conn.execute("""
            INSERT OR REPLACE INTO stop_loss_analytics (
                pair, total_trades, stop_loss_count, stop_loss_rate,
                avg_loss_when_triggered, effectiveness_score, last_updated
            )
            SELECT 
                pair,
                COUNT(*) as total_trades,
                SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) as stop_loss_count,
                AVG(CASE WHEN exit_reason = 'stop_loss' THEN 1.0 ELSE 0.0 END) as stop_loss_rate,
                AVG(CASE WHEN exit_reason = 'stop_loss' THEN profit_pct ELSE NULL END) as avg_loss_when_triggered,
                CASE 
                    WHEN SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END) > 0
                    THEN (SUM(CASE WHEN exit_reason = 'stop_loss' AND profit_pct > -10 THEN 1 ELSE 0 END) * 1.0 / 
                          SUM(CASE WHEN exit_reason = 'stop_loss' THEN 1 ELSE 0 END)) * 100
                    ELSE 0
                END as effectiveness_score,
                CURRENT_TIMESTAMP as last_updated
            FROM trades 
            WHERE is_open = 0 
            GROUP BY pair
        """)
        logging.info("Updated stop loss analytics")
    
    def update_duration_patterns(self, conn):
        """Update trade duration pattern analysis"""
        conn.execute("""
            INSERT OR REPLACE INTO duration_patterns (
                duration_category, trade_count, avg_profit_pct,
                win_rate, optimal_exit_minutes, last_updated
            )
            SELECT 
                CASE 
                    WHEN trade_duration <= 60 THEN 'scalp'
                    WHEN trade_duration <= 480 THEN 'short_term'  
                    WHEN trade_duration <= 1440 THEN 'day_trade'
                    ELSE 'swing_trade'
                END as duration_category,
                COUNT(*) as trade_count,
                AVG(profit_pct) as avg_profit_pct,
                AVG(CASE WHEN profit_pct > 0 THEN 1.0 ELSE 0.0 END) as win_rate,
                AVG(trade_duration) as optimal_exit_minutes,
                CURRENT_TIMESTAMP as last_updated
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
                    INSERT OR REPLACE INTO bot_health_metrics (
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