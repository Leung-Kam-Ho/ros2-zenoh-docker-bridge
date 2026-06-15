#!/bin/bash
cd "$(dirname "$0")/.."

echo "=========================================="
echo "ROS 2 Zenoh Bridge Speed Test (Mac Docker)"
echo "=========================================="

echo "Starting Docker Environment..."
docker-compose up -d --build

echo "Waiting for Zenoh Bridge to connect..."
sleep 5

echo "Starting high-frequency payload publisher..."

docker exec -it ros2_jazzy_node bash -c "source /opt/ros/jazzy/setup.bash && export RMW_IMPLEMENTATION=rmw_fastrtps_cpp && ros2 run demo_nodes_cpp talker"

echo "Done sending."
