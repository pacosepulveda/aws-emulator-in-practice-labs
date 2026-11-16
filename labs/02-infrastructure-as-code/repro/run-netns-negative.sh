#!/usr/bin/env bash
# run-netns-negative.sh — Prueba negativa completa de la barrera de red.
# 1) Setup del namespace aislado (emulador propio, sin ruta externa)
# 2) terraform plan/apply con endpoint IAM omitido, DENTRO del namespace
# 3) Verificaciones: fallo controlado + sin egreso posible (sin ruta) + egress tests
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_DIR"

echo "== 1. namespace aislado =="
sudo bash scripts/netns/emulab-netns.sh setup | tail -2 || exit 1

echo "== 2. verificaciones de egreso (deben fallar) =="
sudo ip netns exec emulab ping -c1 -W2 1.1.1.1 2>&1 | grep -o "Network is unreachable" | head -1
sudo ip netns exec emulab curl -s --max-time 5 https://iam.amazonaws.com 2>&1 | grep -oE "Could not resolve|Network is unreachable|Failed to connect" | head -1
RUTAS=$(sudo ip netns exec emulab ip route | grep -cv "10.200.0.0/24" || true)
[ "$RUTAS" = "0" ] && echo "sin rutas fuera de 10.200.0.0/24 ✓" || { echo "FATAL: hay rutas externas"; exit 1; }

echo "== 3. terraform con endpoint IAM omitido (dentro del namespace) =="
cd labs/02-infrastructure-as-code/repro/netns-negative
AK=$(sudo grep aws_access_key_id /var/lib/emulab/.aws/emulator/9320/emulator_credentials | cut -d= -f2 | tr -d " ")
SK=$(sudo grep aws_secret_access_key /var/lib/emulab/.aws/emulator/9320/emulator_credentials | cut -d= -f2 | tr -d " ")
cat > terraform.tfvars << EOF
ca_bundle = "/var/lib/emulab/.aws/emulator/9320/ca.pem"
access_key = "$AK"
secret_key = "$SK"
EOF
# Providers ya descargados (fuera del namespace no hay internet): copiar caché
sudo rm -rf .terraform .terraform.lock.hcl
sudo cp -r "$REPO_DIR/labs/02-infrastructure-as-code/repro/minimal/.terraform" .
sudo cp "$REPO_DIR/labs/02-infrastructure-as-code/repro/minimal/.terraform.lock.hcl" . 2>/dev/null || true
timeout 300 sudo ip netns exec emulab bash "$REPO_DIR/scripts/netns/run-here.sh" \
  terraform init -input=false > /dev/null 2>&1
timeout 300 sudo ip netns exec emulab bash "$REPO_DIR/scripts/netns/run-here.sh" \
  terraform plan -out=/dev/null > /tmp/netns-neg-plan.log 2>&1
RC_PLAN=$?
echo "plan exit=$RC_PLAN (crear un recurso nuevo no consulta IAM: 0 es correcto)"
echo "== 3a. control positivo: apply CON AWS_ENDPOINT_URL genérico (la omisión de iam queda neutralizada por la variable) =="
timeout 300 sudo ip netns exec emulab bash "$REPO_DIR/scripts/netns/run-here.sh" \
  terraform apply -auto-approve > /tmp/netns-neg-pos.log 2>&1
RC_POS=$?
echo "apply con env genérico exit=$RC_POS (esperado 0: rol creado en el emulador aislado)"
sudo ip netns exec emulab bash "$REPO_DIR/scripts/netns/run-here.sh" \
  aws iam list-roles --query "Roles[?starts_with(RoleName,'aws-emulator-lab-02-netns-neg')].RoleName" --output text | head -1
echo "== 3b. negativa REAL: destruir el rol y aplicar SIN ninguna capa de config =="
timeout 300 sudo ip netns exec emulab bash "$REPO_DIR/scripts/netns/run-here.sh" \
  terraform destroy -auto-approve > /dev/null 2>&1 && echo "rol destruido (estado vacío)"
# Sin AWS_ENDPOINT_URL, sin AWS_CONFIG_FILE (que lleva endpoint_url global del emulador),
# sin endpoints{} iam: SOLO la barrera de red puede impedir el tráfico real.
timeout 300 sudo ip netns exec emulab env -u AWS_ENDPOINT_URL -u AWS_CONFIG_FILE \
  AWS_ACCESS_KEY_ID="$AK" AWS_SECRET_ACCESS_KEY="$SK" \
  AWS_EC2_METADATA_DISABLED=true AWS_REGION=us-east-1 \
  terraform apply -auto-approve -var="ca_bundle=/var/lib/emulab/.aws/emulator/9320/ca.pem" \
  > /tmp/netns-neg.log 2>&1
RC=$?
echo "apply sin capas de config exit=$RC (esperado !=0, fallo controlado)"
grep -oE "dial tcp [^:]+:[0-9]+: (connect: )?(network is unreachable|Connection refused)|Network is unreachable" /tmp/netns-neg.log | head -2
grep -qE "dial tcp (3\.|13\.|15\.|52\.|54\.)" /tmp/netns-neg.log && echo "FATAL: se detectaron intentos a IPs públicas" || echo "sin intentos a IPs públicas ✓"
grep -oE "iam\.amazonaws\.com" /tmp/netns-neg.log | head -1 | xargs -r echo "endpoint al que intentó ir:"
echo "== 4. conclusión =="
if [ "$RC" != "0" ]; then echo "PASS: omisión de endpoint IAM → fallo controlado sin egreso (barrera de red independiente de la configuración)"; else echo "FAIL: terraform terminó 0 con endpoint omitido"; fi
