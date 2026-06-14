#!/bin/bash
# Runs the r2_jazzy container on Linux with host networking and X11 forwarding.
# Usage: ./run_r2_jazzy_linux.sh <container_name> [ROS_DOMAIN_ID]
#   container_name  - name for the container (default: r2_jazzy)
#   ROS_DOMAIN_ID   - optional ROS domain ID (default: 0)

NAME=${1:-r2_jazzy}
DOMAIN_ID=${2:-0}

xhost +local:docker > /dev/null 2>&1

docker run -it --rm \
    --name "$NAME" \
    --network host \
    -e DISPLAY="$DISPLAY" \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -e ROS_DOMAIN_ID="$DOMAIN_ID" \
    -e ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET \
    -e FASTDDS_BUILTIN_TRANSPORTS=UDPv4 \
    r2_jazzy
