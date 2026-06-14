#!/bin/bash
set -euo pipefail

NAME=${1:-r2_jazzy}
DOMAIN_ID=${2:-0}
DISCOVERY_SERVER=${3:-10.0.0.100}
LOCAL=false

for arg in "$@"; do
    [ "$arg" = "--local" ] && LOCAL=true
done

WG_DIR="$(cd "$(dirname "$0")" && pwd)/wg_config"
CONFIG="$WG_DIR/${NAME}.conf"

if [ "$LOCAL" = true ]; then
    docker network inspect r2_jazzy_net >/dev/null 2>&1 || docker network create r2_jazzy_net
    echo "Starting '$NAME' (local mode, domain $DOMAIN_ID)"
    docker run -it --rm \
        --name "$NAME" \
        --network r2_jazzy_net \
        -e DISPLAY=host.docker.internal:0 \
        -e ROS_DOMAIN_ID="$DOMAIN_ID" \
        -e ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET \
        r2_jazzy
elif [ ! -f "$CONFIG" ]; then
    echo "ERROR: No WireGuard config for '$NAME'"
    echo "  Run: ./wg_setup.sh container $NAME"
    exit 1
else
    echo "Starting '$NAME' (WireGuard mode, domain $DOMAIN_ID)"
    echo "  Discovery server: $DISCOVERY_SERVER:11811"
    echo "  Config: $CONFIG"

    WG_IP=$(grep '^Address' "$CONFIG" | head -1 | awk '{print $3}' | cut -d/ -f1)
    mkdir -p /tmp/dds_profiles
    cat > "/tmp/dds_profiles/${NAME}.xml" << EOF
<?xml version="1.0" encoding="UTF-8" ?>
<dds xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
    <profiles>
        <transport_descriptors>
            <transport_descriptor>
                <transport_id>UDPv4Transport</transport_id>
                <type>UDPv4</type>
                <interfaceWhiteList>
                    <address>$WG_IP</address>
                </interfaceWhiteList>
            </transport_descriptor>
        </transport_descriptors>
        <participant profile_name="wg_interface" is_default_profile="true">
            <rtps>
                <userTransports>
                    <transport_id>UDPv4Transport</transport_id>
                </userTransports>
                <useBuiltinTransports>false</useBuiltinTransports>
            </rtps>
        </participant>
    </profiles>
</dds>
EOF

    docker run -it --rm \
        --name "$NAME" \
        --cap-add NET_ADMIN \
        --cap-add SYS_MODULE \
        --sysctl net.ipv4.conf.all.src_valid_mark=1 \
        -v "$CONFIG:/etc/wireguard/wg0.conf:ro" \
        -v "/tmp/dds_profiles/${NAME}.xml:/fastdds_profile.xml:ro" \
        -e DISPLAY=host.docker.internal:0 \
        -e ROS_DOMAIN_ID="$DOMAIN_ID" \
        -e ROS_DISCOVERY_SERVER="$DISCOVERY_SERVER:11811" \
        -e FASTRTPS_DEFAULT_PROFILES_FILE=/fastdds_profile.xml \
        --entrypoint bash \
        r2_jazzy \
        -c "
WG_IP=\"$WG_IP\"
wg-quick up /etc/wireguard/wg0.conf
ip route add 10.0.0.0/24 dev wg0 2>/dev/null || true
echo 'WireGuard up — IP: \$WG_IP'
echo 'ROS 2 ready — run ros2 commands'
bash"
fi
