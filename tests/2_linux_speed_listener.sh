#!/bin/bash
# Load environment variables from .env if it exists
if [ -f "$(dirname "$0")/../.env" ]; then
    export $(grep -v '^#' "$(dirname "$0")/../.env" | xargs)
fi

cd "$(dirname "$0")/.."

echo "=========================================="
echo "ROS 2 Zenoh Bridge Speed Test (Linux Host)"
echo "Domain ID: ${ROS_DOMAIN_ID:-0}"
echo "=========================================="

echo "Starting Advanced Speed Monitor..."
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
python3 tests/speed_monitor.py

echo "Listener stopped."
