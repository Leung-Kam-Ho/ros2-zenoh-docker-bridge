#!/bin/bash
cd "$(dirname "$0")/.."

echo "=========================================="
echo "ROS 2 Zenoh Bridge Speed Test (Mac Docker)"
echo "=========================================="

echo "Starting Docker Environment..."
docker-compose up -d --build

echo "Waiting for Zenoh Bridge to connect..."
sleep 5

echo "Starting high-frequency payload publisher (1MB @ 50Hz)..."

docker exec -it ros2_jazzy_node bash -c "source /opt/ros/jazzy/setup.bash && export RMW_IMPLEMENTATION=rmw_fastrtps_cpp && python3 /root/workspace/tests/blob_talker.py 1048576"

echo "Done sending."
