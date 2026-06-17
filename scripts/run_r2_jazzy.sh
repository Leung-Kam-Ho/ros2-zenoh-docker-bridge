#!/bin/bash
set -euo pipefail
export DISPLAY=:0
xhost +

NAME=${1:-r2_jazzy}
DOMAIN_ID=${2:-0}
DISPLAY_VAL="${DISPLAY:-host.docker.internal:0}"

docker run -it --rm \
    --name "$NAME" \
    --network host \
    -e DISPLAY="docker.for.mac.host.internal:0" \
    -e ROS_DOMAIN_ID="$DOMAIN_ID" \
    -e LIBGL_ALWAYS_INDIRECT=1 \
    -e QT_XCB_GL_INTEGRATION=none \
    r2_jazzy
    