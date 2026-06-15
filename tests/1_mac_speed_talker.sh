#!/bin/bash
cd "$(dirname "$0")/.."

echo "=========================================="
echo "ROS 2 Zenoh Bridge Speed Test (Mac Docker)"
echo "=========================================="

echo "Starting Docker Environment..."
docker-compose up -d --build

echo "Waiting for Zenoh Bridge to connect..."
sleep 5

echo "Stopping any existing talker..."
docker exec ros2_jazzy_node pkill -f blob_talker.py 2>/dev/null || true

# Allow overriding defaults via command line arguments
# Usage: ./tests/1_mac_speed_talker.sh [size_in_bytes] [frequency_hz]
SIZE=${1:-153600}      # Default: 150 KB
FREQ=${2:-100}           # Default: 100 Hz

echo "Starting High-Frequency Test ($((SIZE/1024))KB @ ${FREQ}Hz = $(((SIZE*FREQ)/1024/1024))MB/s Target)..."

docker exec -it ros2_jazzy_node bash -c "source /opt/ros/jazzy/setup.bash && export RMW_IMPLEMENTATION=rmw_fastrtps_cpp && python3 /root/workspace/tests/blob_talker.py $SIZE $FREQ"

echo "Done sending."
