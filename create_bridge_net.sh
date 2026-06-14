#!/usr/bin/env bash
set -euo pipefail

NETWORK_NAME="${NETWORK_NAME:-r2_jazzy_net}"
SUBNET="${SUBNET:-10.88.0.0/24}"
IP_RANGE="${IP_RANGE:-10.88.0.128/25}"
GATEWAY="${GATEWAY:-10.88.0.1}"
CONTAINER_NAME="${CONTAINER_NAME:-jazzy_container}"
IMAGE_NAME="${IMAGE_NAME:-your-image}"
CONTAINER_IP="${CONTAINER_IP:-10.88.0.10}"
HOST_PORT="${HOST_PORT:-8080}"
CONTAINER_PORT="${CONTAINER_PORT:-80}"

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed or not in PATH." >&2
  exit 1
fi

info "Docker Desktop on macOS runs containers inside a VM."
info "So containers on bridge networks are NOT directly reachable as 192.168.31.x from other LAN devices."
info "The supported approach is: private Docker subnet + port mapping via your Mac's IP."

MAC_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
if [[ -z "$MAC_IP" ]]; then
  MAC_IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi

if [[ -n "$MAC_IP" ]]; then
  info "Detected Mac LAN IP: $MAC_IP"
else
  warn "Could not auto-detect Mac LAN IP."
fi

if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  warn "Network '$NETWORK_NAME' already exists. Removing it first."
  docker network rm "$NETWORK_NAME" >/dev/null
fi

info "Creating Docker bridge network: $NETWORK_NAME"
docker network create \
  --driver bridge \
  --subnet "$SUBNET" \
  --ip-range "$IP_RANGE" \
  --gateway "$GATEWAY" \
  "$NETWORK_NAME" >/dev/null

info "Created network '$NETWORK_NAME'"
info "  subnet   = $SUBNET"
info "  ip-range = $IP_RANGE"
info "  gateway  = $GATEWAY"

cat <<EOM

To run a container on this network and expose it to other devices on your LAN:

docker run -d \\
  --name $CONTAINER_NAME \\
  --network $NETWORK_NAME \\
  --ip $CONTAINER_IP \\
  -p $HOST_PORT:$CONTAINER_PORT \\
  $IMAGE_NAME

Other devices should connect to:
  http://<YOUR_MAC_IP>:$HOST_PORT
EOM

if [[ -n "$MAC_IP" ]]; then
  echo "  Example: http://$MAC_IP:$HOST_PORT"
fi

cat <<'EOM'

Useful commands:
  docker network inspect r2_jazzy_net
  docker ps
  docker logs <container>
  docker rm -f <container>
  docker network rm r2_jazzy_net

Notes:
- Do NOT use 192.168.31.0/24 as the Docker bridge subnet on macOS.
- On Docker Desktop for Mac, bridge IPs stay inside Docker's VM.
- If you need a service reachable by your LAN, publish ports with -p.
EOM