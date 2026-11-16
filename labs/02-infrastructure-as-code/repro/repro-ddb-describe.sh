#!/usr/bin/env bash
# repro_ddb_describe.sh — Caso mínimo reproducible: drift falso de DynamoDB en
# Terraform contra AWS Emulator (revisar con docs/research/ddb-describe-analysis.md).
#
# Crea con la CLI la MISMA tabla que crea Terraform (PAY_PER_REQUEST, hash_key pk)
# y vuelca la respuesta de DescribeTable para comparar los campos que devuelve el
# emulador con los que devuelve AWS real (contrato de la API DescribeTable).
#
# Uso: bash repro_ddb_describe.sh [puerto]   (por defecto 9297)
set -euo pipefail
PORT="${1:-9297}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_ID=$(date -u +%Y%m%d%H%M%S)
TABLE="aws-emulator-lab-02-repro-$RUN_ID"
OUT="$REPO_DIR/../results/02-iac/repro-describe-$RUN_ID.json"

export AWS_ENDPOINT_URL="https://127.0.0.1:$PORT" \
       AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/emulator/$PORT/emulator_credentials" \
       AWS_CONFIG_FILE="$HOME/.aws/emulator/$PORT/config" \
       AWS_CA_BUNDLE="$HOME/.aws/emulator/$PORT/ca.pem" \
       AWS_EC2_METADATA_DISABLED=true

echo "== 1. guard STS =="
ACCT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
[ "$ACCT" = "000000000000" ] || { echo "FATAL: identidad '$ACCT' inesperada"; exit 1; }
echo "ok ($ACCT)"

echo "== 2. create-table (idéntico a Terraform: PAY_PER_REQUEST + pk S) =="
aws dynamodb create-table --table-name "$TABLE" \
  --attribute-definitions AttributeName=pk,AttributeType=S \
  --key-schema AttributeName=pk,KeyType=HASH --billing-mode PAY_PER_REQUEST >/dev/null
for i in $(seq 30); do
  S=$(aws dynamodb describe-table --table-name "$TABLE" --query "Table.TableStatus" --output text 2>/dev/null || true)
  [ "$S" = "ACTIVE" ] && break; sleep 1
done
echo "estado: $S"

echo "== 3. DescribeTable completo (JSON crudo) =="
aws dynamodb describe-table --table-name "$TABLE" --output json | tee "$OUT"

echo "== 4. ListTagsOfResource =="
ARN=$(aws dynamodb describe-table --table-name "$TABLE" --query "Table.TableArn" --output text)
aws dynamodb list-tags-of-resource --resource-arn "$ARN" --output json 2>&1 || echo "(no soportado)"

echo "== 5. campos que AWS real SIEMPRE incluye y el provider lee (comparar con $OUT) =="
python3 - "$OUT" << "EOF"
import json, sys
t = json.load(open(sys.argv[1]))["Table"]
CAMPOS_AWS = ["TableArn","TableName","TableStatus","CreationDateTime","ItemCount",
  "TableSizeBytes","KeySchema","AttributeDefinitions","BillingModeSummary",
  "ProvisionedThroughput","DeletionProtectionEnabled","TableClassSummary",
  "StreamSpecification","OnDemandThroughput","Tags","TableId","ReplicaDescriptions"]
presentes = {k: ("—" if k not in t else (t[k] if k not in ("CreationDateTime",) else "…")) for k in CAMPOS_AWS}
print(f"{'campo':30} {'presente':8} valor")
for k, v in presentes.items():
    print(f"{k:30} {'SÍ' if k in t else 'NO':8} {v}")
print()
print("CONCLUSIÓN: los campos ausentes (NO) son los que el provider interpreta")
print("como drift y provocan el reemplazo propuesto en el 2º plan.")
EOF

echo "== 6. limpieza =="
aws dynamodb delete-table --table-name "$TABLE" >/dev/null && echo "tabla eliminada"
