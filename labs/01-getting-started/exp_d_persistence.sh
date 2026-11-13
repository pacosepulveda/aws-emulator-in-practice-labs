#!/usr/bin/env bash
# exp_d_persistence.sh — Experimento D: persistencia tras reinicio y multi-instancia.
# Afirmación de AWS: el estado está SOLO en memoria y SIGTERM lo borra.
# Este experimento VERIFICA el comportamiento observado en vez de asumirlo.
set -uo pipefail
RESULTS="${RESULTS_DIR:-$(pwd)/results/01-getting-started}"
mkdir -p "$RESULTS/logs"

MARK="aws-emulator-lab-01-d-persist"
echo "== D1. Crear recursos de prueba =="
aws s3 mb "s3://$MARK" >/dev/null 2>&1 && echo "bucket $MARK creado" || echo "FALLO creando bucket"

echo "== D2. Detener el emulador (SIGTERM) =="
bash scripts/emulator/stop.sh 9297
sleep 2

echo "== D3. Rearrancar =="
bash scripts/emulator/start.sh 9297
source scripts/common/env.sh 9297

echo "== D4. ¿Sobrevive el bucket? =="
if aws s3 ls | grep -q "$MARK"; then
  echo "RESULT D4: PASS (estado persiste tras reinicio — contradice la doc oficial)"
  aws s3 rb "s3://$MARK" --force >/dev/null
else
  echo "RESULT D4: OBSERVADO-NO-PERSISTE (coincide con la doc: estado solo en memoria)"
fi

echo "== D5. ¿Sobreviven credenciales/certificados? =="
if [ -f "$HOME/.aws/emulator/9297/emulator_credentials" ]; then
  if aws sts get-caller-identity >/dev/null 2>&1; then
    echo "RESULT D5: PASS (credenciales válidas tras reinicio)"
  else
    echo "RESULT D5: PARTIAL (fichero existe pero STS rechaza — credenciales rotadas)"
  fi
else
  echo "RESULT D5: OBSERVADO-NO-PERSISTE (la doc afirma que SIGTERM borra ~/.aws/emulator/<port>)"
fi

echo "== D6. Dos instancias independientes (9297 y 9298) =="
bash scripts/emulator/start.sh 9298
source scripts/common/env.sh 9298
aws s3 mb "s3://$MARK-9298" >/dev/null 2>&1 && echo "bucket creado en 9298"
if aws s3 ls | grep -q "$MARK-9298" && \
   ! (AWS_ENDPOINT_URL=https://127.0.0.1:9297 AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/emulator/9297/emulator_credentials" \
      AWS_CONFIG_FILE="$HOME/.aws/emulator/9297/config" AWS_CA_BUNDLE="$HOME/.aws/emulator/9297/ca.pem" \
      AWS_EC2_METADATA_DISABLED=true aws s3 ls | grep -q "$MARK-9298"); then
  echo "RESULT D6: PASS (aislamiento entre instancias confirmado)"
else
  echo "RESULT D6: revisar (los buckets se ven entre instancias o falló la creación)"
fi

echo "== Limpieza =="
aws s3 rb "s3://$MARK-9298" --force >/dev/null 2>&1
bash scripts/emulator/stop.sh 9298
echo "Experimento D completado — log en $RESULTS/logs/"
