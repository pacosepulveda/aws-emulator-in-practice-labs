#!/usr/bin/env bash
# exp_e_docker.sh — Experimento E (v2): Docker según la doc oficial.
# Diferencias clave con nuestra v0 fallida (ver Dockerfile.initial-failed):
#   - La doc oficial EXIGE -b 0.0.0.0 dentro del contenedor para que Docker
#     pueda redirigir el puerto (el emulador escucha en 127.0.0.1 por defecto).
#   - Publicación restringida a localhost: -p 127.0.0.1:$PORT:$PORT
#   - Volumen compartido ~/.aws/emulator para credenciales y certificados
#   - --user "$(id -u):$(id -g)" en Linux (ficheros propiedad del usuario)
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
PORT="${PORT:-9298}"   # puerto del contenedor (el nativo suele usar 9297)
RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)
RESULTS="$REPO_DIR/results/01-getting-started"
LOGS="$RESULTS/logs"
mkdir -p "$LOGS"
PASS=0; FAIL=0
record() { echo "$1"; [[ "$1" == PASS* || "$1" == OK* ]] && PASS=$((PASS+1)) || FAIL=$((FAIL+1)); }

echo "== E-v2 $RUN_ID — build =="
BUILD_LOG="$LOGS/exp_e_build_${RUN_ID}.log"
if sudo docker build -t aws-emulator:local "$SCRIPT_DIR/docker" > "$BUILD_LOG" 2>&1; then
  DIGEST=$(sudo docker image inspect aws-emulator:local --format '{{index .RepoDigests 0}}' 2>/dev/null || \
           sudo docker image inspect aws-emulator:local --format '{{.Id}}')
  record "PASS build (digest $DIGEST)"
else
  record "FAIL build"; tail -5 "$BUILD_LOG"; exit 1
fi

echo "== arranque con red bridge + publicación en localhost =="
sudo docker rm -f aws-emulator-e >/dev/null 2>&1 || true
mkdir -p "$HOME/.aws/emulator"
# doc oficial Linux: -e HOME + -v + --user
sudo docker run -d --name aws-emulator-e \
  --memory=2g --memory-swap=2g \
  --user "$(id -u):$(id -g)" \
  -e HOME="$HOME" -v "$HOME/.aws/emulator:$HOME/.aws/emulator" \
  -p 127.0.0.1:$PORT:$PORT \
  aws-emulator:local -p $PORT -t off >/dev/null || { record "FAIL docker run"; exit 1; }

for i in $(seq 40); do
  [ -f "$HOME/.aws/emulator/$PORT/ca.pem" ] && \
    curl -sf --cacert "$HOME/.aws/emulator/$PORT/ca.pem" "https://127.0.0.1:$PORT/__admin/health" >/dev/null 2>&1 && break
  sleep 0.5
done
record "PASS health HTTPS (bridge 127.0.0.1:$PORT)"

export E="AWS_ENDPOINT_URL=https://127.0.0.1:$PORT AWS_SHARED_CREDENTIALS_FILE=$HOME/.aws/emulator/$PORT/emulator_credentials AWS_CONFIG_FILE=$HOME/.aws/emulator/$PORT/config AWS_CA_BUNDLE=$HOME/.aws/emulator/$PORT/ca.pem AWS_EC2_METADATA_DISABLED=true AWS_DISABLE_HOST_PREFIX_INJECTION=true"
ACCOUNT=$(env $E aws sts get-caller-identity --query Account --output text 2>/dev/null)
[ "$ACCOUNT" = "000000000000" ] && record "PASS STS" || record "FAIL STS ($ACCOUNT)"

BUCKET="aws-emulator-lab-01-docker-$RUN_ID"
env $E aws s3 mb "s3://$BUCKET" >/dev/null 2>&1 && record "PASS S3 create"
echo contenido > /tmp/e.txt && env $E aws s3 cp /tmp/e.txt "s3://$BUCKET/e.txt" >/dev/null 2>&1 && \
  env $E aws s3 ls "s3://$BUCKET" | grep -q e.txt && record "PASS S3 put/list"
env $E aws dynamodb create-table --table-name "lab01-docker-$RUN_ID" \
  --attribute-definitions AttributeName=pk,AttributeType=S \
  --key-schema AttributeName=pk,KeyType=HASH --billing-mode PAY_PER_REQUEST >/dev/null 2>&1 && \
  sleep 2 && record "PASS DynamoDB create"
env $E aws sqs create-queue --queue-name "lab01-docker-$RUN_ID" >/dev/null 2>&1 && record "PASS SQS create"

# Boto3 contra el contenedor (el propio exp_c con env del puerto $PORT)
AWS_ENDPOINT_URL="https://127.0.0.1:$PORT" \
AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/emulator/$PORT/emulator_credentials" \
AWS_CONFIG_FILE="$HOME/.aws/emulator/$PORT/config" \
AWS_CA_BUNDLE="$HOME/.aws/emulator/$PORT/ca.pem" \
"$REPO_DIR/.venv/bin/python" "$SCRIPT_DIR/exp_c_boto3.py" >/dev/null 2>&1 \
  && record "PASS Boto3 (exp_c completo contra contenedor)" || record "FAIL Boto3"

# Aislamiento de LAN: la DIRECCIÓN LOCAL (campo 5) debe ser 127.0.0.1 o [::1]
LOCAL_ADDR=$(ss -tln | awk -v p=":$PORT" '$4 ~ p {print $4}' | head -1)
if [[ "$LOCAL_ADDR" == 127.0.0.1:$PORT || "$LOCAL_ADDR" == "[::1]:$PORT" ]]; then
  record "PASS aislamiento LAN (bind $LOCAL_ADDR)"
else
  record "FAIL aislamiento LAN — bind local: ${LOCAL_ADDR:-ninguno}"
fi

# Dos instancias simultáneas (nativa 9297 + contenedor $PORT)
bash "$REPO_DIR/scripts/emulator/start.sh" 9297 >/dev/null 2>&1
A=$(AWS_ENDPOINT_URL=https://127.0.0.1:9297 AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/emulator/9297/emulator_credentials" AWS_CONFIG_FILE="$HOME/.aws/emulator/9297/config" AWS_CA_BUNDLE="$HOME/.aws/emulator/9297/ca.pem" AWS_EC2_METADATA_DISABLED=true aws s3 mb s3://aws-emulator-lab-01-e-native 2>&1 && echo ok)
[ "$A" = "ok" ] && record "PASS instancia nativa coexiste con contenedor"
env $E aws s3 ls | grep -q e-native && record "FAIL aislamiento (bucket nativo visible en contenedor)" || record "PASS aislamiento de recursos nativo/contenedor"
aws s3 rb s3://aws-emulator-lab-01-e-native --force >/dev/null 2>&1

# Certificados/credenciales: propiedad de los ficheros del volumen (usuario)
OWNER=$(stat -c '%U' "$HOME/.aws/emulator/$PORT/ca.pem" 2>/dev/null)
[ "$OWNER" = "$(id -un)" ] && record "PASS cert/creds con propiedad del usuario (--user uid:gid)" \
  || record "FAIL propiedad cert/creds ($OWNER)"

# Limpieza
env $E aws s3 rb "s3://$BUCKET" --force >/dev/null 2>&1
env $E aws dynamodb delete-table --table-name "lab01-docker-$RUN_ID" >/dev/null 2>&1
env $E aws sqs delete-queue --queue-url "$(env $E aws sqs get-queue-url --queue-name "lab01-docker-$RUN_ID" --output text 2>/dev/null)" >/dev/null 2>&1
sudo docker rm -f aws-emulator-e >/dev/null 2>&1
bash "$REPO_DIR/scripts/emulator/stop.sh" 9297 >/dev/null 2>&1
echo "== E-v2 fin: $PASS PASS / $FAIL FAIL (run $RUN_ID) =="
[ "$FAIL" -eq 0 ]
