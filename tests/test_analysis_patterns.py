"""Exercise the shipped generic analysis patterns with small in-memory data."""

from decimal import Decimal
from pathlib import Path
import unittest

import duckdb


class AnalysisPatterns(unittest.TestCase):
    def setUp(self):
        self.connection = duckdb.connect(":memory:")
        self.addCleanup(self.connection.close)
        source = Path(__file__).resolve().parents[1] / "assets" / "analysis-patterns.sql"
        self.queries = self.connection.extract_statements(source.read_text(encoding="utf-8"))
        self.connection.execute("""
            CREATE TABLE order_lines(order_id INT, amount DECIMAL(18,2));
            INSERT INTO order_lines VALUES (1, 10.00), (1, 20.00), (2, 7.00);
            CREATE TABLE refund_events(order_id INT, refund_amount DECIMAL(18,2));
            INSERT INTO refund_events VALUES (1, 2.00), (1, 3.00);
            CREATE TABLE daily_segment_metrics(
                segment VARCHAR, converted_cnt BIGINT, eligible_cnt BIGINT
            );
            INSERT INTO daily_segment_metrics VALUES ('a', 1, 2), ('a', 1, 8), ('b', 0, 0);
            CREATE TABLE fact_events(
                event_id INT, customer_id INT, event_time TIMESTAMP
            );
            INSERT INTO fact_events VALUES
                (10, 1, '2026-01-01 12:00:00'),
                (11, 1, '2026-01-02 00:00:00'),
                (12, 2, '2026-01-02 00:00:00');
            CREATE TABLE dim_customer_history(
                history_id INT, customer_id INT, region VARCHAR,
                valid_from TIMESTAMP, valid_to TIMESTAMP
            );
            INSERT INTO dim_customer_history VALUES
                (1, 1, 'old', '2026-01-01', '2026-01-02'),
                (2, 1, 'new', '2026-01-02', NULL);
        """)

    def run_pattern(self, index):
        return self.connection.execute(self.queries[index]).fetchall()

    def test_fact_join_preserves_amounts(self):
        self.assertEqual(
            sorted(self.run_pattern(0)),
            [(1, Decimal("30.00"), Decimal("5.00")), (2, Decimal("7.00"), Decimal("0.00"))],
        )

    def test_ratio_rollup_is_weighted_and_zero_is_undefined(self):
        result = dict(self.run_pattern(1))
        self.assertAlmostEqual(result["a"], 0.2)
        self.assertIsNone(result["b"])

    def test_history_join_uses_half_open_boundaries(self):
        self.assertEqual(sorted(self.run_pattern(2)), [(10, "old"), (11, "new"), (12, None)])

    def test_grain_check_detects_duplicate_event(self):
        self.assertEqual(self.run_pattern(3), [])
        self.connection.execute(
            "INSERT INTO fact_events VALUES (10, 1, '2026-01-01 12:00:00')"
        )
        self.assertEqual(self.run_pattern(3), [(10, 2)])

    def test_history_check_detects_overlapping_open_interval(self):
        self.assertEqual(self.run_pattern(4), [])
        self.connection.execute(
            "INSERT INTO dim_customer_history VALUES (3, 1, 'overlap', '2026-01-01 12:00:00', NULL)"
        )
        self.assertEqual(sorted(self.run_pattern(4)), [(1, 1, 3), (1, 2, 3)])


if __name__ == "__main__":
    unittest.main()
