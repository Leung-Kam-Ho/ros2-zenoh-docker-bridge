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

# Allow overriding defaults via command line arguments
# Usage: ./tests/3_linux_speed_talker.sh [size_in_bytes] [frequency_hz]
SIZE=${1:-153600}      # Default: 150 KB
FREQ=${2:-100}         # Default: 100 Hz

echo "Starting High-Frequency Test ($((SIZE/1024))KB @ ${FREQ}Hz = $(((SIZE*FREQ)/1024/1024))MB/s Target)..."

export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export FASTRTPS_DEFAULT_PROFILES_FILE=$(pwd)/fastdds_tuning.xml
python3 tests/blob_talker.py $SIZE $FREQ
