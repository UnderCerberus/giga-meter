import unittest
from datetime import datetime, timedelta, timezone

from refresh_watch import Install, evaluate, parse_time

JST = timezone(timedelta(hours=9))
NOW = datetime(2026, 11, 8, 12, 0, tzinfo=JST)


def install(days_old=0.0, error="", failures=0, ttl=7):
    return Install(
        name="ギガメーター",
        last_updated=NOW - timedelta(days=days_old),
        ttl_days=ttl,
        last_error=error,
        failures=failures,
    )


class EvaluateTests(unittest.TestCase):
    def test_recent_refresh_is_quiet(self):
        self.assertIsNone(evaluate(install(days_old=4), NOW))

    def test_warns_when_two_days_remain(self):
        alert = evaluate(install(days_old=5), NOW)
        self.assertIn("あと2日", alert.body)

    def test_reports_expired(self):
        alert = evaluate(install(days_old=7.5), NOW)
        self.assertIn("切れた", alert.title)

    def test_reports_failure_even_with_time_left(self):
        alert = evaluate(install(days_old=1, error="session expired", failures=1), NOW)
        self.assertIn("失敗", alert.title)
        self.assertIn("session expired", alert.body)

    def test_expired_wins_over_failure(self):
        alert = evaluate(install(days_old=8, failures=2), NOW)
        self.assertIn("切れた", alert.title)

    def test_missing_install_is_reported(self):
        alert = evaluate(None, NOW)
        self.assertIn("見つからない", alert.title)


class ParseTimeTests(unittest.TestCase):
    def test_parses_sideloadly_timestamp_with_seven_digit_fraction(self):
        parsed = parse_time("2026-11-02 00:25:08.0529533+09:00")
        self.assertEqual(parsed, datetime(2026, 11, 2, 0, 25, 8, 52953, tzinfo=JST))

    def test_parses_timestamp_without_fraction(self):
        parsed = parse_time("2026-11-02 00:25:08+09:00")
        self.assertEqual(parsed, datetime(2026, 11, 2, 0, 25, 8, tzinfo=JST))


if __name__ == "__main__":
    unittest.main()
