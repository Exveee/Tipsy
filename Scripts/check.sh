#!/usr/bin/env bash
#
# Local CI: build the package, then run the TipsyCheck test runner.
# Replaces the old GitHub Actions workflow — runs with the Swift toolchain
# only (Command Line Tools is enough; no Xcode required).
#
# Usage: ./Scripts/check.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Building (swift build)"
swift build --package-path "$ROOT"

echo "==> Testing (swift run TipsyCheck)"
swift run --package-path "$ROOT" TipsyCheck
