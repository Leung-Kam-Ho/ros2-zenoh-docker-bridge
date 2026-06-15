#!/bin/bash
cd "$(dirname "$0")"

ARCH=$(uname -m)

if [ "$ARCH" = "x86_64" ]; then
    echo "Downloading Zenoh ROS2 Bridge for x86_64 (amd64)..."
    curl -L -o zenoh-bridge-ros2dds.zip https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds/releases/download/1.9.0/zenoh-plugin-ros2dds-1.9.0-x86_64-unknown-linux-gnu-standalone.zip
elif [ "$ARCH" = "aarch64" ]; then
    echo "Downloading Zenoh ROS2 Bridge for aarch64 (arm64)..."
    curl -L -o zenoh-bridge-ros2dds.zip https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds/releases/download/1.9.0/zenoh-plugin-ros2dds-1.9.0-aarch64-unknown-linux-gnu-standalone.zip
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

sudo apt-get install -y unzip
unzip -o zenoh-bridge-ros2dds.zip
chmod +x zenoh-bridge-ros2dds

echo "Zenoh ROS2 Bridge installed locally!"
