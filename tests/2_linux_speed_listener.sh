#!/bin/bash
cd "$(dirname "$0")/.."

echo "=========================================="
echo "ROS 2 Zenoh Bridge Speed Test (Linux Host)"
echo "=========================================="

echo "Starting Advanced Speed Monitor..."
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
python3 tests/speed_monitor.py

echo "Listener stopped."
