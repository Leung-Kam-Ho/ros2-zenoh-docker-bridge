#!/bin/bash
# WireGuard setup for cross-device ROS 2 communication (offline).
# Generates keys and configs for both Mac + Linux.
#
# Usage:
#   ./wg_setup.sh                    # Interactive setup
#   ./wg_setup.sh mac                # Generate Mac config only
#   ./wg_setup.sh linux <mac_ip>     # Generate Linux config with Mac's LAN IP
#
# The Mac runs a WireGuard Docker sidecar; ROS 2 containers share its network.
# Linux runs WireGuard natively; ROS 2 uses --network host.

set -e

WG_DIR="$(cd "$(dirname "$0")" && pwd)/wg_config"
mkdir -p "$WG_DIR"

# Generate a key pair inside Docker (avoids requiring wg-tools on the host)
gen_keys() {
    local label="$1"
    if [ -f "$WG_DIR/${label}_private" ] && [ -f "$WG_DIR/${label}_public" ]; then
        echo "  Keys for $label already exist, using existing"
        return
    fi
    echo "  Generating keys for $label..."
    docker run --rm --entrypoint sh linuxserver/wireguard -c "
        umask 077
        priv=\$(wg genkey)
        pub=\$(echo \"\$priv\" | wg pubkey)
        echo \"\$priv\" > /tmp/priv
        echo \"\$pub\" > /tmp/pub
        cat /tmp/priv
        cat /tmp/pub
    " > "$WG_DIR/${label}_keys.tmp" 2>/dev/null
    head -1 "$WG_DIR/${label}_keys.tmp" > "$WG_DIR/${label}_private"
    tail -1 "$WG_DIR/${label}_keys.tmp" > "$WG_DIR/${label}_public"
    rm "$WG_DIR/${label}_keys.tmp"
    echo "  Keys saved to $WG_DIR/${label}_{private,public}"
}

case "${1:-all}" in
    mac|all)
        echo "=== Mac WireGuard setup ==="
        gen_keys "mac"
        MAC_PRIV=$(cat "$WG_DIR/mac_private")
        MAC_PUB=$(cat "$WG_DIR/mac_public")

        # Generate the peer config snippet for Linux
        cat > "$WG_DIR/linux_peer.conf" << EOF
[Peer]
# Mac WireGuard sidecar
PublicKey = $MAC_PUB
Endpoint = <MAC_LAN_IP>:51820
AllowedIPs = 10.0.0.1/32
PersistentKeepalive = 25
EOF
        echo "  Linux peer config saved to $WG_DIR/linux_peer.conf"

        # Print Mac connection details for Docker compose
        cat > "$WG_DIR/mac_docker.conf" << EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $MAC_PRIV

# Linux peer — add the public key and endpoint after running ./wg_setup.sh linux
EOF
        echo "  Mac base config saved to $WG_DIR/mac_docker.conf"
        echo "  Done. Run './wg_setup.sh linux' on the Linux machine,"
        echo "  then run './run_wireguard_sidecar.sh' to start."
        echo ""
        echo "  Linux machine needs:"
        echo "    sudo apt install wireguard-tools"
        echo "    sudo cp wg_config/linux_wg.conf /etc/wireguard/wg0.conf"
        echo "    sudo wg-quick up wg0"
        echo "    sudo sysctl -w net.ipv4.ip_forward=1"
        echo "    Also forward ROS_DOMAIN_ID=1 on both sides"
        ;;
    linux)
        echo "=== Linux WireGuard setup ==="
        if [ -z "$2" ]; then
            echo "Usage: $0 linux <MAC_LAN_IP>"
            echo "  e.g., $0 linux 192.168.31.248"
            exit 1
        fi
        MAC_LAN_IP="$2"

        gen_keys "linux"
        LINUX_PRIV=$(cat "$WG_DIR/linux_private")
        LINUX_PUB=$(cat "$WG_DIR/linux_public")

        if [ -f "$WG_DIR/mac_public" ]; then
            MAC_PUB=$(cat "$WG_DIR/mac_public")
        else
            echo "ERROR: Mac keys not found. Run './wg_setup.sh mac' first on the Mac."
            exit 1
        fi

        # Generate Linux WireGuard config
        cat > "$WG_DIR/linux_wg.conf" << EOF
[Interface]
Address = 10.0.0.2/24
PrivateKey = $LINUX_PRIV
# Optional: listen on a specific port for incoming connections
# ListenPort = 51820

[Peer]
# Mac WireGuard sidecar (Docker)
PublicKey = $MAC_PUB
Endpoint = $MAC_LAN_IP:51820
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
EOF

        echo "  Linux config saved to $WG_DIR/linux_wg.conf"
        echo ""
        echo "  To apply on Linux:"
        echo "    sudo cp wg_config/linux_wg.conf /etc/wireguard/wg0.conf"
        echo "    sudo wg-quick up wg0"
        echo ""
        echo "  Then update the Mac's peer config:"
        echo "  Add this to $WG_DIR/mac_docker.conf:"
        echo ""
        echo "  [Peer]"
        echo "  PublicKey = $LINUX_PUB"
        echo "  AllowedIPs = 10.0.0.2/32"
        echo ""

        # Update Mac's peer config
        cat > "$WG_DIR/mac_peer_linux.conf" << EOF
[Peer]
PublicKey = $LINUX_PUB
AllowedIPs = 10.0.0.2/32
EOF
        echo "  Mac peer config saved to $WG_DIR/mac_peer_linux.conf"
        echo ""
        echo "  Then restart the WireGuard sidecar on the Mac"
        ;;
    *)
        echo "Usage:"
        echo "  $0                    # Interactive (full setup)"
        echo "  $0 mac                # Generate Mac keys + config"
        echo "  $0 linux <mac_ip>     # Generate Linux config (run on Linux)"
        ;;
esac
