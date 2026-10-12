#!/usr/bin/env bash
# Prints the -only-testing flags for one shard of the iPhone UI tests.
#
#   usage: ui-test-shard.sh <shard 1..N> <shard-count>
#
# Classes are found by scanning FitnessAppUITests/, so new test classes join a
# shard without editing the workflow. Each class is weighted by its number of
# test methods and handed greedily to the lightest shard, which keeps the
# shards roughly even. The screenshot classes are not run in CI.
set -euo pipefail

shard=${1:?shard number (1-based)}
count=${2:?shard count}
dir="$(cd "$(dirname "$0")/../.." && pwd)/FitnessAppUITests"

for file in "$dir"/*.swift; do
  class=$(sed -nE 's/^(final )?class ([A-Za-z0-9_]+): XCTestCase.*/\2/p' "$file" | head -1)
  case "$class" in
    "" | ScreenshotTests | IPadScreenshotTests) continue ;;
  esac
  tests=$(grep -cE '^[[:space:]]*func test' "$file" || true)
  echo "$tests $class"
done | sort -k1,1nr -k2,2 | awk -v shard="$shard" -v count="$count" '
  {
    best = 1
    for (s = 2; s <= count; s++) if (load[s] < load[best]) best = s
    load[best] += ($1 > 0 ? $1 : 1)
    if (best == shard) print "-only-testing:FitnessAppUITests/" $2
  }'
