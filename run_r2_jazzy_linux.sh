#!/bin/bash
# Runs the r2_jazzy container on Linux with host networking and X11 forwarding.
# Usage: ./run_r2_jazzy_linux.sh <container_name> [ROS_DOMAIN_ID] [DISCOVERY_SERVER_IP]
#   container_name      - name for the container (default: r2_jazzy)
#   ROS_DOMAIN_ID       - optional ROS domain ID (default: 0)
#   DISCOVERY_SERVER_IP - optional discovery server IP (also used as peer for cross-device)
#
# Uses --network host so the container shares the host's LAN IP directly.
# Generates a Fast DDS XML profile with listening_ports and initialPeersList
# so cross-device communication with Mac Docker containers works.

NAME=${1:-r2_jazzy}
DOMAIN_ID=${2:-0}
DISCOVERY_SERVER=${3:-}
PEER_IP=${4:-}

# Port range matching the Mac container's calculation
NAME_HASH=$(echo -n "$NAME" | cksum | awk '{print $1}')
PORT_OFFSET=$(( (NAME_HASH % 100) * 5 ))
DDS_PB=7400
DDS_PORT_START=$((DDS_PB + DOMAIN_ID * 250 + PORT_OFFSET))
DDS_PORT_END=$((DDS_PORT_START + 4))

DISCOVERY_ARGS=""
DDS_ARGS=""

if [ -n "$DISCOVERY_SERVER" ]; then
    DISCOVERY_ARGS="-e ROS_DISCOVERY_SERVER=$DISCOVERY_SERVER:11811"

    mkdir -p /tmp/dds_profiles

    # Use the discovery server IP as peer if no explicit peer given
    TARGET_PEER=${PEER_IP:-$DISCOVERY_SERVER}

    cat > "/tmp/dds_profiles/${NAME}.xml" << EOF
<?xml version="1.0" encoding="UTF-8" ?>
<dds xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
    <profiles>
        <transport_descriptors>
            <transport_descriptor>
                <transport_id>UDPv4Transport</transport_id>
                <type>UDPv4</type>
                <listening_ports>
EOF
    for p in $(seq "$DDS_PORT_START" "$DDS_PORT_END"); do
        echo "                    <port>$p</port>" >> "/tmp/dds_profiles/${NAME}.xml"
    done
    cat >> "/tmp/dds_profiles/${NAME}.xml" << EOF
                </listening_ports>
            </transport_descriptor>
        </transport_descriptors>
        <participant profile_name="cross_device" is_default_profile="true">
            <rtps>
                <userTransports>
                    <transport_id>UDPv4Transport</transport_id>
                </userTransports>
                <useBuiltinTransports>false</useBuiltinTransports>
                <builtin>
                    <initialPeersList>
                        <locator>
                            <udpv4>
                                <address>$TARGET_PEER</address>
                                <port>$DDS_PORT_START</port>
                            </udpv4>
                        </locator>
                    </initialPeersList>
                </builtin>
            </rtps>
        </participant>
    </profiles>
</dds>
EOF

    DDS_ARGS="-v /tmp/dds_profiles/${NAME}.xml:/fastdds_profile.xml:ro \
              -e FASTRTPS_DEFAULT_PROFILES_FILE=/fastdds_profile.xml"
fi

xhost +local:docker > /dev/null 2>&1

docker run -it --rm \
    --name "$NAME" \
    --network host \
    -e DISPLAY="$DISPLAY" \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -e ROS_DOMAIN_ID="$DOMAIN_ID" \
    -e FASTDDS_BUILTIN_TRANSPORTS=UDPv4 \
    $DISCOVERY_ARGS \
    $DDS_ARGS \
    r2_jazzy
