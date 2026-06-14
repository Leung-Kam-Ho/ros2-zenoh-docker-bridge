#!/bin/bash
# Generates a Fast DDS XML profile for native ROS 2 on Linux
# so it can communicate with a Docker container on the Mac.
#
# Usage: ./gen_native_profile.sh <container_name> <mac_ip> [ROS_DOMAIN_ID]
#   container_name  - name of the Mac container to connect to
#   mac_ip          - Mac's LAN IP
#   ROS_DOMAIN_ID   - ROS domain ID (default: 0)

NAME=${1:?Usage: $0 <container_name> <mac_ip> [ROS_DOMAIN_ID]}
MAC_IP=${2:?Usage: $0 <container_name> <mac_ip> [ROS_DOMAIN_ID]}
DOMAIN_ID=${3:-0}

NAME_HASH=$(echo -n "$NAME" | cksum | awk '{print $1}')
PORT_OFFSET=$(( (NAME_HASH % 100) * 5 ))
DDS_PB=7400
DDS_PORT=$((DDS_PB + DOMAIN_ID * 250 + PORT_OFFSET))

cat << EOF
<?xml version="1.0" encoding="UTF-8" ?>
<dds xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
    <profiles>
        <transport_descriptors>
            <transport_descriptor>
                <transport_id>UDPv4Transport</transport_id>
                <type>UDPv4</type>
                <listening_ports>
                    <port>$DDS_PORT</port>
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
                                <address>$MAC_IP</address>
                                <port>$DDS_PORT</port>
                            </udpv4>
                        </locator>
                    </initialPeersList>
                </builtin>
            </rtps>
        </participant>
    </profiles>
</dds>
EOF
