#!/usr/bin/env bash
# exp_b_aws_cli.sh — Experimento B: AWS CLI contra el emulador (STS/S3/DynamoDB/SQS).
# Requisitos de revisión v2:
#   - STS es PRECONDICIÓN: si falla, aborta sin crear recursos (exit 1)
#   - run_id único por ejecución; timestamps ISO 8601; exit != 0 si falla algo obligatorio
#   - limpieza con trap INCLUSO con errores; incluye buckets versionados,
#     delete markers, tablas DynamoDB y colas SQS del proyecto
# Requiere: source scripts/common/env.sh (valida cuenta 000000000000)
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
RESULTS="${RESULTS_DIR:-$REPO_DIR/results/01-getting-started}"
RUN_ID="$(date -u +%Y%m%d%H%M%S)$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-6)"
LOG="$RESULTS/logs/exp_b_${RUN_ID}.log"
mkdir -p "$RESULTS/logs"
exec > >(tee -a "$LOG") 2>&1
FAILED=0
S3B="aws-emulator-lab-01-b-${RUN_ID}"
TBL="aws-emulator-lab-01-b-${RUN_ID}"
QNAME="aws-emulator-lab-01-b-${RUN_ID}"
TS() { date -u +%Y-%m-%dT%H:%M:%SZ; }

cleanup() {
  echo "[$(TS)] limpieza garantizada (trap)…"
  # bucket versionado: eliminar todas las versiones y delete markers antes de rb
  aws s3api delete-objects --bucket "$S3B" \
    --delete "$(aws s3api list-object-versions --bucket "$S3B" \
      --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' 2>/dev/null)" >/dev/null 2>&1
  aws s3api delete-objects --bucket "$S3B" \
    --delete "$(aws s3api list-object-versions --bucket "$S3B" \
      --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' 2>/dev/null)" >/dev/null 2>&1
  aws s3 rb "s3://$S3B" --force >/dev/null 2>&1
  aws dynamodb delete-table --table-name "$TBL" >/dev/null 2>&1
  aws sqs delete-queue --queue-url "$(aws sqs get-queue-url --queue-name "$QNAME" --query QueueUrl --output text 2>/dev/null)" >/dev/null 2>&1
  echo "[$(TS)] limpieza completada"
}
trap cleanup EXIT

step() { echo; echo "=== $1 [$(TS)] ==="; }
result() {  # result <ID> <PASS|FAIL|...> [detalle]
  echo "RESULT $1: $2 ${3:+— $3}"
  [[ "$2" != PASS* && "$2" != OK* ]] && FAILED=$((FAILED+1))
  return 0
}

# ---- PRECONDICIÓN: identidad (aborta sin crear recursos si falla) ----
step "B0. PRECONDICIÓN: identidad STS"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || ACCOUNT="FALLO"
if [ "$ACCOUNT" != "000000000000" ]; then
  echo "FATAL: identidad inesperada ('$ACCOUNT'). No se creará ningún recurso." >&2
  exit 1
fi
echo "identidad OK (cuenta $ACCOUNT) — run $RUN_ID"

t0=$(date +%s.%N)

step "B1. S3: crear bucket y round-trip de objeto"
aws s3 mb "s3://$S3B" >/dev/null 2>&1 && \
echo "contenido-$(date +%s)" > /tmp/demo-object.txt && \
aws s3 cp /tmp/demo-object.txt "s3://$S3B/demo-object.txt" >/dev/null 2>&1 && \
aws s3 cp "s3://$S3B/demo-object.txt" /tmp/demo-down.txt >/dev/null 2>&1 && \
diff -q /tmp/demo-object.txt /tmp/demo-down.txt >/dev/null 2>&1 && \
aws s3 rm "s3://$S3B/demo-object.txt" >/dev/null 2>&1 \
  && result B1 PASS "create/put/copy/get/delete" || result B1 FAIL

step "B2. S3: versionado + round-trip versionado + delete marker"
aws s3api put-bucket-versioning --bucket "$S3B" \
  --versioning-configuration Status=Enabled >/dev/null 2>&1 && \
aws s3 cp /tmp/demo-object.txt "s3://$S3B/v.txt" >/dev/null 2>&1 && \
aws s3 cp /tmp/demo-object.txt "s3://$S3B/v.txt" >/dev/null 2>&1 && \
NV=$(aws s3api list-object-versions --bucket "$S3B" --prefix v.txt --query 'length(Versions)' --output text 2>/dev/null) && \
aws s3 rm "s3://$S3B/v.txt" >/dev/null 2>&1 && \
NDM=$(aws s3api list-object-versions --bucket "$S3B" --prefix v.txt --query 'length(DeleteMarkers)' --output text 2>/dev/null) && \
echo "versiones=$NV delete_markers=$NDM" && \
{ [ "$NV" = "2" ] && [ "$NDM" = "1" ] && result B2 PASS "2 versiones + 1 delete marker" \
  || result B2 FAIL "versiones=$NV markers=$NDM"; }

step "B3. S3: cifrado por defecto y Block Public Access (representación de config)"
aws s3api put-bucket-encryption --bucket "$S3B" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' >/dev/null 2>&1 \
  && aws s3api get-bucket-encryption --bucket "$S3B" 2>/dev/null | grep -q AES256 \
  && aws s3api put-public-access-block --bucket "$S3B" \
       --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true >/dev/null 2>&1 \
  && aws s3api get-public-access-block --bucket "$S3B" 2>/dev/null | grep -q RestrictPublicBuckets \
  && result B3 "PASS (representación)" "config almacenada y devuelta; NO implica aplicación efectiva de controles (art. 03)" \
  || result B3 FAIL

step "B4. DynamoDB: create + wait ACTIVE + put/get"
aws dynamodb create-table --table-name "$TBL" \
  --attribute-definitions AttributeName=pk,AttributeType=S \
  --key-schema AttributeName=pk,KeyType=HASH --billing-mode PAY_PER_REQUEST >/dev/null 2>&1 \
  && { for _ in $(seq 40); do \
         ST=$(aws dynamodb describe-table --table-name "$TBL" --query "Table.TableStatus" --output text 2>/dev/null || echo none); \
         [ "$ST" = "ACTIVE" ] && break; sleep 0.25; done; } \
  && aws dynamodb put-item --table-name "$TBL" --item '{"pk":{"S":"item1"},"valor":{"S":"demo"}}' >/dev/null 2>&1 \
  && aws dynamodb get-item --table-name "$TBL" --key '{"pk":{"S":"item1"}}' 2>/dev/null | grep -q demo \
  && result B4 PASS || result B4 FAIL

step "B5. SQS: create + send + receive íntegro"
QURL=$(aws sqs create-queue --queue-name "$QNAME" --query QueueUrl --output text 2>/dev/null)
if [ -n "${QURL:-}" ] && [ "$QURL" != "None" ]; then
  aws sqs send-message --queue-url "$QURL" --message-body "mensaje-$RUN_ID" >/dev/null 2>&1 \
    && MSG=$(aws sqs receive-message --queue-url "$QURL" --max-number-of-messages 1 --query 'Messages[0].Body' --output text 2>/dev/null) \
    && [ "$MSG" = "mensaje-$RUN_ID" ] && result B5 PASS "mensaje recibido íntegro" || result B5 FAIL
else
  result B5 FAIL "no se pudo crear la cola"
fi

t1=$(date +%s.%N)
DUR=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}')
echo
echo "RESUMEN run $RUN_ID: $FAILED fallos · duración ${DUR}s · $(TS)"
exit "$FAILED"
