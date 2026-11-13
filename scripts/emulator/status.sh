#!/usr/bin/env bash
# status.sh — salud + identidad + consumo de recursos del emulador.
set -euo pipefail
PORT="${1:-9297}"
EMU_DIR="$HOME/.aws/emulator/$PORT"
echo "== Proceso =="
pgrep -af "aws-emulator" || echo "NO EJECUTÁNDOSE"
echo "== Salud =="
if [ -f "$EMU_DIR/ca.pem" ]; then
  curl -s --cacert "$EMU_DIR/ca.pem" "https://127.0.0.1:${PORT}/__admin/health" \
    && echo " (health OK)" || echo "health FAIL"
else
  echo "sin certificado en $EMU_DIR"
fi
echo "== Identidad STS =="
if command -v aws >/dev/null && [ -f "$EMU_DIR/emulator_credentials" ]; then
  AWS_ENDPOINT_URL="https://127.0.0.1:${PORT}" \
  AWS_SHARED_CREDENTIALS_FILE="$EMU_DIR/emulator_credentials" \
  AWS_CONFIG_FILE="$EMU_DIR/config" \
  AWS_CA_BUNDLE="$EMU_DIR/ca.pem" \
  AWS_EC2_METADATA_DISABLED=true \
  aws sts get-caller-identity || true
fi
echo "== Recursos =="
PID=$(pgrep -x aws-emulator | head -1 || true)
if [ -n "$PID" ]; then
  ps -p "$PID" -o pid,rss,vsz,etime,cmd --no-headers
fi
