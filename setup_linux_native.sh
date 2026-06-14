#!/bin/bash
# Setup native ROS 2 on Linux to communicate with Mac Docker containers
# via WireGuard tunnel. Saves an XML profile and exports env vars.
#
# Usage:
#   source ./setup_linux_native.sh              # exports env vars for current shell
#   source ./setup_linux_native.sh <domain_id>  # specify ROS_DOMAIN_ID (default: 0)
#
# Or run a command directly:
#   ./setup_linux_native.sh ros2 topic list
#   ./setup_linux_native.sh ros2 run demo_nodes_cpp listener

PROFILE_DIR="${XDG_RUNTIME_DIR:-/tmp}/dds_profiles"
mkdir -p "$PROFILE_DIR"

DOMAIN_ID="${1:-0}"

# If first arg looks like a number, shift it
if [[ "$1" =~ ^[0-9]+$ ]]; then
    shift
fi

cat > "$PROFILE_DIR/linux_wg_profile.xml" << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8" ?>
<dds xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
    <profiles>
        <transport_descriptors>
            <transport_descriptor>
                <transport_id>UDPv4Transport</transport_id>
                <type>UDPv4</type>
                <interfaceWhiteList>
                    <address>10.0.0.2</address>
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
XMLEOF

export FASTRTPS_DEFAULT_PROFILES_FILE="$PROFILE_DIR/linux_wg_profile.xml"
export ROS_DISCOVERY_SERVER="10.0.0.100:11811"
export ROS_DOMAIN_ID="$DOMAIN_ID"
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp

# Also source ROS 2 if available
if [ -f /opt/ros/jazzy/setup.bash ]; then
    source /opt/ros/jazzy/setup.bash
fi

echo "=== Linux Native ROS 2 → Mac Docker ==="
echo "  ROS_DOMAIN_ID:          $DOMAIN_ID"
echo "  ROS_DISCOVERY_SERVER:   10.0.0.2:11811 (run: fastdds discovery -i 0 -l 10.0.0.2 -p 11811)"
echo "  FASTRTPS_PROFILE:       wg0-only (10.0.0.2)"
echo ""

if [ $# -gt 0 ]; then
    exec "$@"
else
    echo "Ready. Run ROS 2 commands manually in this shell."
    echo "  Example: ros2 run demo_nodes_cpp listener"
fi
