#!/bin/bash
# Runs the r2_jazzy container with GUI and network support.
# Usage: ./run_r2_jazzy.sh <container_name> [ROS_DOMAIN_ID] [DISCOVERY_SERVER_IP]
#   container_name     - name for the container (default: r2_jazzy)
#   ROS_DOMAIN_ID      - optional ROS domain ID (default: 0)
#   DISCOVERY_SERVER_IP - optional Fast DDS discovery server IP for cross-device comm

NAME=${1:-r2_jazzy}
DOMAIN_ID=${2:-0}
# DISCOVERY_SERVER=${3:-}


DISCOVERY_ARGS="-e ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET"
if [ -n "$DISCOVERY_SERVER" ]; then
    DISCOVERY_ARGS="-e ROS_DISCOVERY_SERVER=$DISCOVERY_SERVER:11811"
fi

docker run -it --rm \
    --name "$NAME" \
    --network r2_jazzy_net \
    -e DISPLAY=host.docker.internal:0 \
    -e ROS_DOMAIN_ID="$DOMAIN_ID" \
    r2_jazzy

    # $DISCOVERY_ARGS \
    # -e FASTDDS_BUILTIN_TRANSPORTS=UDPv4 \