#!/bin/bash
# Load environment variables from .env if it exists
if [ -f "$(dirname "$0")/../.env" ]; then
    export $(grep -v '^#' "$(dirname "$0")/../.env" | xargs)
fi

echo "Checking ROS 2 Discovery on Domain: ${ROS_DOMAIN_ID:-0}"
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp

echo "--- Topic List ---"
ros2 topic list

echo ""
echo "--- Speed Test Topic Info ---"
ros2 topic info /speed_test_topic --verbose
