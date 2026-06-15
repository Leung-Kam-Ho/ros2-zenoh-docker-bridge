#!/bin/bash
cd "$(dirname "$0")"

if [ ! -f "./zenoh-bridge-dds" ]; then
    echo "zenoh-bridge-dds not found. Please run 1_install_zenoh.sh first."
    exit 1
fi

echo "Starting Zenoh DDS Bridge on Native Linux (Listening on TCP 7447)..."
echo "Allowing all DDS topics via regex: .*"
export RUST_LOG=info
./zenoh-bridge-dds -l tcp/0.0.0.0:7447 -a ".*"
