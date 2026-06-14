#!/bin/bash
set -e
WG_DIR="$(cd "$(dirname "$0")" && pwd)/wg_config"
mkdir -p "$WG_DIR"

gen_keys() {
    local label="$1"
    mkdir -p "$WG_DIR"
    if [ -f "$WG_DIR/${label}_private" ]; then
        echo "  Keys for $label already exist"
        return
    fi
    echo "  Generating keys for $label..."
    if command -v wg >/dev/null 2>&1; then
        local priv pub
        priv=$(umask 077; wg genkey)
        pub=$(echo "$priv" | wg pubkey)
        echo "$priv" > "$WG_DIR/${label}_private"
        echo "$pub"  > "$WG_DIR/${label}_public"
    else
        docker pull -q linuxserver/wireguard > /dev/null 2>&1 || true
        local tmp
        tmp=$(docker run --rm --entrypoint sh linuxserver/wireguard -c "
            umask 077
            priv=\$(wg genkey)
            echo \"\$priv\"
            echo \"\$priv\" | wg pubkey
        " 2>/dev/null)
        echo "$tmp" | sed -n '1p' > "$WG_DIR/${label}_private"
        echo "$tmp" | sed -n '2p' > "$WG_DIR/${label}_public"
    fi
    echo "  Keys saved"
}

case "${1:-all}" in
    mac|all)
        echo "=== Mac Host Setup ==="
        gen_keys "mac"
        MAC_PUB=$(cat "$WG_DIR/mac_public")

        cat > "$WG_DIR/wg0.conf" << EOF
[Interface]
Address = 10.0.0.1/32
ListenPort = 51820
PrivateKey = $(cat "$WG_DIR/mac_private")

# Linux peer — add after running 'wg_setup.sh linux ...'
# Container peers — added by 'wg_setup.sh container ...'
EOF
        echo "  Mac host config: $WG_DIR/wg0.conf"
        echo "  Mac public key:  $MAC_PUB"
        echo ""
        echo "  On Linux: ./wg_setup.sh linux <MAC_LAN_IP>"
        echo "  On Mac:   ./wg_setup.sh container <name>"
        ;;
    linux)
        if [ -z "$2" ]; then
            echo "Usage: $0 linux <MAC_LAN_IP>"
            echo "  e.g., $0 linux 192.168.31.248"
            exit 1
        fi
        echo "=== Linux Setup ==="
        gen_keys "linux"
        LINUX_PUB=$(cat "$WG_DIR/linux_public")

        if [ ! -f "$WG_DIR/mac_public" ]; then
            echo "ERROR: Copy wg_config/mac_public from Mac first"
            exit 1
        fi
        MAC_PUB=$(cat "$WG_DIR/mac_public")

        sudo tee /etc/wireguard/wg0.conf > /dev/null << EOF
[Interface]
Address = 10.0.0.2/24
ListenPort = 51820
PrivateKey = $(cat "$WG_DIR/linux_private")

[Peer]
PublicKey = $MAC_PUB
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
EOF
        echo "  Linux config: /etc/wireguard/wg0.conf"
        echo "  Start: sudo wg-quick up wg0"
        echo ""
        echo "=== Add container peers to Mac host ($WG_DIR/wg0.conf) ==="
        echo "Run: ./wg_setup.sh container <name>"
        echo "This adds the [Peer] block for each container."
        ;;
    container)
        if [ -z "$2" ]; then
            echo "Usage: $0 container <NAME> [CONTAINER_IP]"
            echo "  e.g., $0 container talker 10.0.0.10"
            exit 1
        fi
        NAME="$2"
        IP="${3:-10.0.0.10}"
        echo "=== Container '$NAME' Setup (IP: $IP) ==="

        gen_keys "$NAME"

        if [ ! -f "$WG_DIR/linux_public" ]; then
            echo "ERROR: First run './wg_setup.sh linux <MAC_LAN_IP>' on Linux and copy wg_config/"
            exit 1
        fi
        LINUX_PUB=$(cat "$WG_DIR/linux_public")

        cat > "$WG_DIR/${NAME}.conf" << EOF
[Interface]
Address = $IP/32
PrivateKey = $(cat "$WG_DIR/${NAME}_private")

[Peer]
PublicKey = $LINUX_PUB
Endpoint = 192.168.31.249:51820
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
EOF
        echo "  Container config: $WG_DIR/${NAME}.conf"
        echo "  Container IP: $IP"
        echo ""

        echo "=== Also add this peer to Mac host ($WG_DIR/wg0.conf) ==="
        echo "[Peer]"
        echo "PublicKey = $(cat "$WG_DIR/${NAME}_public")"
        echo "AllowedIPs = $IP/32"
        echo ""
        echo "Then: docker compose restart or restart the sidecar."
        echo "Run container: ./run_r2_jazzy.sh $NAME"
        ;;
esac
