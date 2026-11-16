#!/usr/bin/env bash
# run-here.sh — Run a command INSIDE the isolated namespace with the isolated
# emulator's environment. Usage:
#   sudo ip netns exec emulab bash scripts/netns/run-here.sh <command...>
set -euo pipefail
PORT=9320
NS_HOME="/var/lib/emulab"
export HOME="$NS_HOME"
export AWS_ENDPOINT_URL="https://127.0.0.1:$PORT" \
       AWS_SHARED_CREDENTIALS_FILE="$NS_HOME/.aws/emulator/$PORT/emulator_credentials" \
       AWS_CONFIG_FILE="$NS_HOME/.aws/emulator/$PORT/config" \
       AWS_CA_BUNDLE="$NS_HOME/.aws/emulator/$PORT/ca.pem" \
       AWS_EC2_METADATA_DISABLED=true AWS_REGION=us-east-1
ACCT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
[ "$ACCT" = "000000000000" ] || { echo "FATAL: unexpected identity '$ACCT'"; exit 1; }
exec "$@"
