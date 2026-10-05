#!/usr/bin/env bash
# scaffold.sh – seeds a Python module whose parse_duration drops all but the last unit.
#
# Usage:
#   claude plugin eval --scaffold runs it in the case's workspace
#
# What it does:
#   1. Seeds duration.py with the bug and test_duration.py with a passing test
set -euo pipefail

cat > duration.py <<'PY'
import re

UNITS = {"h": 3600, "m": 60, "s": 1}


def parse_duration(text):
    """Return the number of seconds in a duration such as '1h30m' or '45s'."""
    total = 0
    for amount, unit in re.findall(r"(\d+)([hms])", text):
        total = int(amount) * UNITS[unit]
    return total
PY

cat > test_duration.py <<'PY'
import unittest

from duration import parse_duration


class ParseDurationTest(unittest.TestCase):
    def test_seconds(self):
        self.assertEqual(parse_duration("45s"), 45)

    def test_hours(self):
        self.assertEqual(parse_duration("2h"), 7200)


if __name__ == "__main__":
    unittest.main()
PY
