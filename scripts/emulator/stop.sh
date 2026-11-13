#!/usr/bin/env bash
# stop.sh — detiene ÚNICAMENTE la instancia gestionada por este proyecto en el
# puerto indicado. Valida la identidad del proceso antes de matarlo; nunca
# detiene instancias de otros puertos ni procesos ajenos.
set -euo pipefail
PORT="${1:-9297}"
RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/aws-emulator-in-practice"
PIDFILE="$RUN_DIR/aws-emulator-${PORT}.pid"
mkdir -p "$RUN_DIR"

if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE" 2>/dev/null || true)
  # Validación de identidad: el PID debe existir, ser aws-emulator y usar NUESTRO puerto
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null \
     && ps -p "$PID" -o comm= 2>/dev/null | grep -qx "aws-emulator" \
     && tr '\0' ' ' < "/proc/$PID/cmdline" 2>/dev/null | grep -q -- "-p ${PORT}"; then
    kill -TERM "$PID"
    for _ in $(seq 10); do kill -0 "$PID" 2>/dev/null || break; sleep 1; done
    if kill -0 "$PID" 2>/dev/null; then
      echo "AVISO: SIGTERM no bastó; SIGKILL a $PID (solo esta instancia)" >&2
      kill -KILL "$PID" 2>/dev/null || true
    fi
    echo "✅ Emulador del puerto $PORT detenido (pid $PID)"
  else
    echo "PID obsoleto o no corresponde al puerto $PORT — no se detiene nada"
  fi
  rm -f "$PIDFILE"
else
  # Sin pidfile: avisar si algo vive en ese puerto, pero no tocarlo
  if curl -sk --cacert "$HOME/.aws/emulator/${PORT}/ca.pem" \
       "https://127.0.0.1:${PORT}/__admin/health" >/dev/null 2>&1; then
    echo "AVISO: hay un emulador vivo en el puerto $PORT sin pidfile de este proyecto; NO se detiene"
  else
    echo "No hay emulador en el puerto $PORT"
  fi
fi
