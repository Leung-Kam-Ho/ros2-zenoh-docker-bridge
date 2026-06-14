#!/bin/bash
# Runs the r2_jazzy container with GUI and network support on macOS.
# Usage: ./run_r2_jazzy.sh <container_name> [ROS_DOMAIN_ID] [DISCOVERY_SERVER_IP] [PEER_IP]
#   container_name     - name for the container (default: r2_jazzy)
#   ROS_DOMAIN_ID      - optional ROS domain ID (default: 0)
#   DISCOVERY_SERVER_IP - optional discovery server IP (also used to reach this container)
#   PEER_IP            - optional peer (e.g., native Linux) IP for direct communication
#
# When DISCOVERY_SERVER_IP is set, the container publishes DDS ports and generates
# a Fast DDS XML profile to bind to known ports. When PEER_IP is also set, it adds
# an initialPeersList entry so the container connects directly to the Linux machine.

NAME=${1:-r2_jazzy}
DOMAIN_ID=${2:-0}
DISCOVERY_SERVER=${3:-}
PEER_IP=${4:-}

# Unique port range per container (name-hashed, 5 ports each)
NAME_HASH=$(echo -n "$NAME" | cksum | awk '{print $1}')
PORT_OFFSET=$(( (NAME_HASH % 100) * 5 ))
DDS_PB=7400
DDS_PORT_START=$((DDS_PB + DOMAIN_ID * 250 + PORT_OFFSET))
DDS_PORT_END=$((DDS_PORT_START + 4))

DISCOVERY_ARGS="-e ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET"
DDS_ARGS=""
PORT_ARGS=""
SOCAT_PIDS=""

if [ -n "$DISCOVERY_SERVER" ]; then
    DISCOVERY_ARGS="-e ROS_DISCOVERY_SERVER=$DISCOVERY_SERVER:11811"

    mkdir -p /tmp/dds_profiles

    # Build XML with listening_ports (valid) and optional initialPeersList
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

    if [ -n "$PEER_IP" ]; then
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
                                <address>$PEER_IP</address>
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
    else
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
            </rtps>
        </participant>
    </profiles>
</dds>
EOF
    fi

    DDS_ARGS="-v /tmp/dds_profiles/${NAME}.xml:/fastdds_profile.xml:ro \
              -e FASTRTPS_DEFAULT_PROFILES_FILE=/fastdds_profile.xml"

    for p in $(seq "$DDS_PORT_START" "$DDS_PORT_END"); do
        PORT_ARGS="$PORT_ARGS -p $p:$p/udp"
    done
fi

echo "Starting container '$NAME' with domain ID $DOMAIN_ID"
echo "  DDS ports: $DDS_PORT_START-$DDS_PORT_END"
[ -n "$DISCOVERY_SERVER" ] && echo "  Discovery server: $DISCOVERY_SERVER:11811"
[ -n "$PEER_IP" ] && echo "  Peer (initialPeersList): $PEER_IP:$DDS_PORT_START"

docker run -it --rm \
    --name "$NAME" \
    --network r2_jazzy_net \
    $PORT_ARGS \
    -e DISPLAY=host.docker.internal:0 \
    -e ROS_DOMAIN_ID="$DOMAIN_ID" \
    -e FASTDDS_BUILTIN_TRANSPORTS=UDPv4 \
    $DISCOVERY_ARGS \
    $DDS_ARGS \
    r2_jazzy
