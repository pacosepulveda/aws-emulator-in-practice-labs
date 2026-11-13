#!/usr/bin/env bash
# env.sh — configura el shell para usar SOLO el emulador local, nunca AWS real.
# Uso: source scripts/common/env.sh [PUERTO]
# Controles anti-AWS-real:
#   1. AWS_ENDPOINT_URL explícito al emulador local
#   2. Archivos de credenciales/config independientes (solo los del emulador)
#   3. Variables de credenciales reales eliminadas del entorno
#   4. Búsqueda de credenciales en metadatos EC2 desactivada
#   5. Host prefix injection desactivada (SDKs)
#   6. Verificación de identidad STS: cuenta esperada 000000000000
set -euo pipefail

PORT="${1:-9297}"
EMU_DIR="$HOME/.aws/emulator/$PORT"

if [ ! -f "$EMU_DIR/emulator_credentials" ]; then
  echo "ERROR: no hay credenciales del emulador en $EMU_DIR" >&2
  echo "¿Está el emulador arrancado? Ejecuta: make start" >&2
  return 1 2>/dev/null || exit 1
fi

# 3. Eliminar credenciales reales del entorno (tienen prioridad sobre ficheros)
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE || true

export AWS_ENDPOINT_URL="https://127.0.0.1:${PORT}"
export AWS_SHARED_CREDENTIALS_FILE="$EMU_DIR/emulator_credentials"
export AWS_CONFIG_FILE="$EMU_DIR/config"
export AWS_CA_BUNDLE="$EMU_DIR/ca.pem"
export AWS_EC2_METADATA_DISABLED=true
export AWS_DISABLE_HOST_PREFIX_INJECTION=true
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
export EMULATOR_PORT="$PORT"

# 6. Validación del endpoint antes de operar
ACCOUNT="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo FALLO)"
if [ "$ACCOUNT" != "000000000000" ]; then
  echo "ERROR DE SEGURIDAD: STS devolvió cuenta '$ACCOUNT' (esperada: 000000000000)." >&2
  echo "Las peticiones NO están yendo al emulador. NO ejecutes operaciones de creación." >&2
  return 1 2>/dev/null || exit 1
fi
echo "✅ Entorno del emulador activo (puerto $PORT, cuenta $ACCOUNT, endpoint $AWS_ENDPOINT_URL)"
