# Contributing to Real-time Trading Analytics Automation

Thank you for your interest in contributing to this project! This document provides guidelines and instructions for contributing.

## How to Contribute

### Reporting Issues

1. Check existing issues to avoid duplicates
2. Use the issue template when creating new issues
3. Include:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - System information (OS, Python version)
   - Relevant log excerpts

### Suggesting Enhancements

1. Check if the enhancement has already been suggested
2. Open an issue with the "enhancement" label
3. Clearly describe:
   - The proposed feature
   - Use cases and benefits
   - Potential implementation approach

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests if applicable
5. Update documentation
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to your branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## Development Setup

### 1. Clone Your Fork

```bash
git clone https://github.com/YOUR_USERNAME/Real-time-Trading-Analytics-Automation.git
cd Real-time-Trading-Analytics-Automation
```

### 2. Set Up Development Environment

```bash
python3 -m venv venv_dev
source venv_dev/bin/activate
pip install -r requirements.txt
```

### 3. Create Test Database

For development, create a test database with sample data:

```python
# create_test_db.py
import sqlite3
from datetime import datetime, timedelta
import random

# Create test database
conn = sqlite3.connect('test_trading.db')
cursor = conn.cursor()

# Create trades table
cursor.execute('''
    CREATE TABLE IF NOT EXISTS trades (
        trade_id INTEGER PRIMARY KEY,
        pair TEXT NOT NULL,
        base_currency TEXT NOT NULL,
        quote_currency TEXT NOT NULL,
        is_open BOOLEAN NOT NULL,
        strategy TEXT NOT NULL,
        profit_pct REAL,
        profit_abs REAL,
        profit_ratio REAL,
        trade_duration INTEGER,
        exit_reason TEXT,
        stop_loss_pct REAL,
        stake_amount REAL,
        open_date DATETIME,
        close_date DATETIME
    )
''')

# Generate sample trades
pairs = ['BTC/USDT', 'ETH/USDT', 'ADA/USDT', 'DOT/USDT']
strategies = ['Strategy001', 'Strategy002', 'Strategy003']
exit_reasons = ['roi', 'stop_loss', 'exit_signal', 'force_exit']

for i in range(100):
    pair = random.choice(pairs)
    base, quote = pair.split('/')
    strategy = random.choice(strategies)
    profit_pct = random.uniform(-5, 5)
    trade_duration = random.randint(30, 1440)
    
    cursor.execute('''
        INSERT INTO trades VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (
        i + 1, pair, base, quote, 0, strategy,
        profit_pct, profit_pct * 10, profit_pct / 100,
        trade_duration, random.choice(exit_reasons),
        -2.0, 100.0,
        datetime.now() - timedelta(days=random.randint(1, 30)),
        datetime.now() - timedelta(days=random.randint(0, 1))
    ))

conn.commit()
conn.close()
```

## Code Style Guidelines

### Python Style

- Follow PEP 8
- Use descriptive variable names
- Add docstrings to all functions and classes
- Keep functions focused and single-purpose

### SQL Style

- Use uppercase for SQL keywords
- Use meaningful table and column names
- Add comments for complex queries
- Properly format multi-line queries

### Example Code Style

```python
def update_analytics_table(self, conn: sqlite3.Connection) -> None:
    """
    Update the analytics table with current metrics.
    
    Args:
        conn: SQLite database connection
        
    Returns:
        None
        
    Raises:
        sqlite3.Error: If database operation fails
    """
    try:
        conn.execute("""
            INSERT OR REPLACE INTO analytics_table (
                metric_name, metric_value, last_updated
            )
            SELECT 
                'example_metric' as metric_name,
                AVG(value) as metric_value,
                CURRENT_TIMESTAMP as last_updated
            FROM source_table
            WHERE condition = true
        """)
        logging.info("Updated analytics table successfully")
    except sqlite3.Error as e:
        logging.error(f"Failed to update analytics: {e}")
        raise
```

## Testing

### Running Tests

```bash
# Run all tests
python -m pytest

# Run with coverage
python -m pytest --cov=trading_analytics_automation_final

# Run specific test
python -m pytest tests/test_analytics.py::test_performance_rankings
```

### Writing Tests

```python
# tests/test_analytics.py
import unittest
from trading_analytics_automation_final import TradingAnalyticsAutomator

class TestAnalytics(unittest.TestCase):
    def setUp(self):
        self.automator = TradingAnalyticsAutomator('test_trading.db')
    
    def test_performance_rankings(self):
        # Test implementation
        pass
```

## Documentation

- Update README.md for user-facing changes
- Update API_DOCUMENTATION.md for code changes
- Include docstrings in all new functions
- Add inline comments for complex logic

## Commit Message Guidelines

Follow the conventional commits specification:

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes
- `refactor:` Code refactoring
- `test:` Test additions or changes
- `chore:` Maintenance tasks

Examples:
```
feat: add real-time alerts for critical health status
fix: correct stop-loss calculation in risk metrics
docs: update installation guide for Windows support
```

## Questions?

Feel free to open an issue for any questions about contributing!