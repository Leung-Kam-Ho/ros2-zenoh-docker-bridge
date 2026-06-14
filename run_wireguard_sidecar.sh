#!/bin/bash
set -euo pipefail

WITH_DISCOVERY=false
for arg in "$@"; do
    [ "$arg" = "--with-discovery" ] && WITH_DISCOVERY=true
done

docker network inspect r2_jazzy_net >/dev/null 2>&1 || docker network create r2_jazzy_net

if [ "$WITH_DISCOVERY" = true ]; then
    docker rm -f r2_jazzy_discovery_server 2>/dev/null || true
    docker run -d --rm \
        --name r2_jazzy_discovery_server \
        --network r2_jazzy_net \
        -p 11811:11811/udp \
        r2_jazzy \
        fastdds discovery -i 0 -l 0.0.0.0 -p 11811
    echo "Discovery server started on r2_jazzy_net (port 11811)"
    echo ""
    echo "ROS containers (Mac): ./run_r2_jazzy.sh <name> <domain> <discovery_server_bridge_ip>"
    echo "  Find bridge IP: docker inspect r2_jazzy_discovery_server | jq -r '.[0].NetworkSettings.Networks.r2_jazzy_net.IPAddress'"
    echo "Linux native:         export ROS_DISCOVERY_SERVER=10.0.0.10:11811"
fi
