#!/bin/bash
cd "$(dirname "$0")/.."

echo "=========================================="
echo "ROS 2 Zenoh Bridge Speed Test (Linux Host)"
echo "=========================================="

echo "Starting listener to measure bandwidth (1MB messages)..."
echo "This will show the data rate and bandwidth from the Mac/Windows talker."
echo "Press Ctrl+C to stop."

export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
ros2 topic bw /speed_test_topic

echo "Listener stopped."
