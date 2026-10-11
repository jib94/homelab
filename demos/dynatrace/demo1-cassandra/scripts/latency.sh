#!/usr/bin/env bash
# Print the last N one-minute points of the demo latency metric (reads dynatrace/metric.conf).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/../dynatrace/metric.conf"
MINUTES="${1:-15}"
dtctl query "timeseries p95=avg(${METRIC_KEY}), by:{${DIM_NODE}}, from:now()-${MINUTES}m | filter ${DIM_NODE} == \"cassandra-0\"" -o json \
  | python3 -I -c "import sys,json; r=json.load(sys.stdin)['result']['records']; [print(x['p95']) for x in r]"
