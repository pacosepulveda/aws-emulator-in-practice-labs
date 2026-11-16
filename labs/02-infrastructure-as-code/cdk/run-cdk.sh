#!/usr/bin/env bash
# cdk_app.sh — Lab 02 I-5: AWS CDK contra AWS Emulator (misma arquitectura lógica
# que Terraform/CloudFormation: S3 + DynamoDB + SQS).
#
# Uso: bash cdk_app.sh apply|destroy   (ejecutar desde labs/02-infrastructure-as-code/cdk/)
# Requisitos: node >= 18, aws-cdk CLI, cd cdk-app && npm install
set -euo pipefail
PORT="${PORT:-9297}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # labs/
ACTION="${1:-apply}"

# Endpoints del emulador para el CLI y para CDK (los constructs usan props/endpoints
# vía variables de entorno que el provider interno del CDK respeta)
export AWS_ENDPOINT_URL="https://127.0.0.1:$PORT" \
       AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/emulator/$PORT/emulator_credentials" \
       AWS_CONFIG_FILE="$HOME/.aws/emulator/$PORT/config" \
       AWS_CA_BUNDLE="$HOME/.aws/emulator/$PORT/ca.pem" \
       AWS_EC2_METADATA_DISABLED=true \
       AWS_REGION=us-east-1 \
       CDK_DEFAULT_REGION=us-east-1 \
       CDK_DEFAULT_ACCOUNT=000000000000

# Guard STS
ACCT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
[ "$ACCT" = "000000000000" ] || { echo "FATAL: identidad '$ACCT' inesperada"; exit 1; }
echo "guard STS ok ($ACCT)"

cd "$REPO_DIR/cdk/cdk-app"
RUN_ID="cdk$(date -u +%Y%m%d%H%M%S)"
if [ "$ACTION" = "apply" ]; then
  npx cdk deploy --require-approval never \
    -c runId="$RUN_ID" \
    -c endpoint="https://127.0.0.1:$PORT" \
    -c caBundle="$HOME/.aws/emulator/$PORT/ca.pem" 2>&1
else
  npx cdk destroy --require-approval never -c runId="$RUN_ID" \
    -c endpoint="https://127.0.0.1:$PORT" \
    -c caBundle="$HOME/.aws/emulator/$PORT/ca.pem" 2>&1 || true
fi
