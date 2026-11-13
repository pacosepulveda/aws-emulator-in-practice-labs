#!/usr/bin/env bash
# start.sh — arranca el emulador como usuario sin privilegios, telemetría OFF, localhost.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${1:-9297}"
LOG="${LOGDIR:-$(pwd)/results/01-getting-started/logs}/emulator-${PORT}-$(date -u +%Y%m%dT%H%M%SZ).log"
RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/aws-emulator-in-practice"
PIDFILE="$RUN_DIR/aws-emulator-${PORT}.pid"
mkdir -p "$(dirname "$LOG")" "$RUN_DIR"

# Telemetría OFF a nivel de máquina (requisito del proyecto)
mkdir -p "$HOME/.aws/emulator"
grep -q "telemetry enabled false" "$HOME/.aws/emulator/config.toml" 2>/dev/null \
  || echo 'telemetry enabled false' >> "$HOME/.aws/emulator/config.toml"

# Guard por puerto: health check específico (pgrep -f matchearía otros emuladores
# y también el propio comando que nos invoca — no usar pgrep aquí)
CA_CHECK="$HOME/.aws/emulator/${PORT}/ca.pem"
if [ -f "$CA_CHECK" ] && curl -sf --cacert "$CA_CHECK" "https://127.0.0.1:${PORT}/__admin/health" >/dev/null 2>&1; then
  echo "El emulador del puerto $PORT ya está en ejecución."
  exit 0
fi
# Residuo sin salud pero con pidfile (crash previo): limpiar el pidfile
rm -f "$PIDFILE"

echo "Arrancando emulador en puerto $PORT (telemetría off, localhost)..."
T0=$(date +%s.%N)
nohup aws-emulator -p "$PORT" -t off > "$LOG" 2>&1 &
EMU_PID=$!
echo "$EMU_PID" > "$PIDFILE"

# Espera de salud: /__admin/health con el certificado generado (máx 30 s)
for _ in $(seq 60); do
  CA="$HOME/.aws/emulator/${PORT}/ca.pem"
  if [ -f "$CA" ] && curl -sf --cacert "$CA" "https://127.0.0.1:${PORT}/__admin/health" >/dev/null 2>&1; then
    T1=$(date +%s.%N)
    awk -v a="$T0" -v b="$T1" -v p="$EMU_PID" -v port="$PORT" \
      'BEGIN{printf "✅ Emulador saludable (pid %s, https://127.0.0.1:%s) — arranque: %.2f s\n", p, port, b-a}'
    exit 0
  fi
  sleep 0.5
done
echo "ERROR: el emulador no respondió al health check en 30 s. Log: $LOG" >&2
exit 1
