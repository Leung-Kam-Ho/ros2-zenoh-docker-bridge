#!/bin/bash
cd "$(dirname "$0")"

if [ ! -f "./zenoh-bridge-ros2dds" ]; then
    echo "zenoh-bridge-ros2dds not found. Please run 1_install_zenoh.sh first."
    exit 1
fi

echo "Starting Zenoh ROS2 Bridge on Native Linux (Listening on TCP 7447)..."
export RUST_LOG=debug
./zenoh-bridge-ros2dds --listen tcp/0.0.0.0:7447
