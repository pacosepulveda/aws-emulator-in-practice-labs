#!/usr/bin/env bash
# emulab-netns.sh — Independent network barrier for the experiments (lab 02+).
#
# Design: a network namespace WITHOUT a default route runs ITS OWN emulator
# instance (127.0.0.1:9320). Anything executed inside the namespace has no path
# to the internet: an omitted endpoint in the configuration produces an
# immediate, controlled failure with no outgoing packets.
#
# The isolated instance uses HOME=/var/lib/emulab (credentials and CA generated
# by the emulator itself under /var/lib/emulab/.aws/emulator/9320).
set -euo pipefail
NETNS="${NETNS:-emulab}"
VETH_HOST="${VETH_HOST:-v-emulab}"
VETH_PEER="${VETH_PEER:-v-emulab-p}"
HOST_IP="10.200.0.1"; NS_IP="10.200.0.2"; PORT=9320
NS_HOME="/var/lib/emulab"
EMU_BIN="${EMU_BIN:-$(command -v aws-emulator || echo /usr/bin/aws-emulator)}"

ns() { sudo ip netns exec "$NETNS" "$@"; }

case "${1:-status}" in
  setup)
    sudo ip netns list | grep -q "$NETNS" || sudo ip netns add "$NETNS"
    ns ip link set lo up 2>/dev/null || true   # loopback up is REQUIRED
    sudo ip link show "$VETH_HOST" >/dev/null 2>&1 || {
      sudo ip link add "$VETH_HOST" type veth peer name "$VETH_PEER"
      sudo ip link set "$VETH_PEER" netns "$NETNS"
      sudo ip addr add "$HOST_IP/24" dev "$VETH_HOST"
      sudo ip link set "$VETH_HOST" up
      sudo ip netns exec "$NETNS" ip addr add "$NS_IP/24" dev "$VETH_PEER"
      sudo ip netns exec "$NETNS" ip link set "$VETH_PEER" up
    }
    echo "routes in $NETNS (only 10.200.0.0/24 must exist):"
    sudo ip netns exec "$NETNS" ip route
    # NO default route: nothing can leave the namespace.
    sudo mkdir -p "$NS_HOME"
    sudo chown 1000:1000 "$NS_HOME" 2>/dev/null || true
    ns env HOME="$NS_HOME" "$EMU_BIN" -b 127.0.0.1 -p $PORT -t off > /tmp/emulab-$PORT.log 2>&1 &
    echo $! > /tmp/emulab-$PORT.pid
    for i in $(seq 40); do
      [ -f "$NS_HOME/.aws/emulator/$PORT/ca.pem" ] && \
        ns curl -sf --cacert "$NS_HOME/.aws/emulator/$PORT/ca.pem" "https://127.0.0.1:$PORT/__admin/health" 2>/dev/null | grep -q ok && break
      sleep 0.5
    done
    ns curl -sf --cacert "$NS_HOME/.aws/emulator/$PORT/ca.pem" "https://127.0.0.1:$PORT/__admin/health" >/dev/null \
      && echo "isolated emulator OK: https://127.0.0.1:$PORT (inside $NETNS)" \
      || { echo "FATAL: health check timed out"; exit 1; }
    echo "creds/CA: $NS_HOME/.aws/emulator/$PORT/"
    ;;
  stop)
    [ -f /tmp/emulab-$PORT.pid ] && sudo kill "$(cat /tmp/emulab-$PORT.pid)" 2>/dev/null || true
    sudo ip netns del "$NETNS" 2>/dev/null || true
    sudo ip link del "$VETH_HOST" 2>/dev/null || true
    echo "namespace $NETNS removed"
    ;;
  status)
    sudo ip netns list | grep "$NETNS" || echo "$NETNS: not present"
    ;;
esac
