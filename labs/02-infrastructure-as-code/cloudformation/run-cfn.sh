#!/usr/bin/env bash
# run-cfn.sh — recreate the I-4 procedure (create → update → deploy via change
# sets → delete) against a LOCAL emulator. Guard: local endpoint only.
set -euo pipefail
ENDPOINT="${AWS_ENDPOINT_URL:-https://127.0.0.1:9297}"
case "$(uname -p)" in x86_64) : ;; *) : ;; esac
case "$ENDPOINT" in
  https://127.0.0.1:*|https://localhost:*|http://127.0.0.1:*) ;;
  *) echo "GUARD FAIL: endpoint must be local ($ENDPOINT)"; exit 1 ;;
esac
DIR="$(cd "$(dirname "$0")" && pwd)"
STACK=seclab-cfn
echo "== create-stack =="
aws cloudformation create-stack --stack-name "$STACK" --endpoint-url "$ENDPOINT" \
  --template-body "file://$DIR/template.yaml" \
  --parameters ParameterKey=EnvironmentName,ParameterValue=seclab >/dev/null
echo "== update-stack (new parameter value) =="
aws cloudformation update-stack --stack-name "$STACK" --endpoint-url "$ENDPOINT" \
  --template-body "file://$DIR/template.yaml" \
  --parameters ParameterKey=EnvironmentName,ParameterValue=seclab2 >/dev/null || echo "(no update needed)"
echo "== deploy via change sets =="
aws cloudformation deploy --stack-name "$STACK" --endpoint-url "$ENDPOINT" \
  --template-file "$DIR/template.yaml" --capabilities CAPABILITY_IAM \
  --parameter-overrides EnvironmentName=seclab3
echo "== delete-stack =="
aws cloudformation delete-stack --stack-name "$STACK" --endpoint-url "$ENDPOINT"
aws cloudformation wait stack-delete-complete --stack-name "$STACK" --endpoint-url "$ENDPOINT" 2>/dev/null || true
echo "done"
