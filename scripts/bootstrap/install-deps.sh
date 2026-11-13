#!/usr/bin/env bash
# install-deps.sh — bootstrap de la VM del laboratorio (procedimientos oficiales).
# Ejecutar como usuario con sudo. Idempotente.
#
# SEGURIDAD: todas las verificaciones criptográficas son fail-closed:
#  - GNUPGHOME temporal y aislado (no depende del keyring del usuario)
#  - verificación legible por máquina con gpg --status-file (GOODSIG/EXPKEYSIG...)
#  - fingerprint completo verificado explícitamente antes de ejecutar nada con sudo
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Versiones fijadas del laboratorio (reproducibilidad; ver docs/research/)
AWS_EMULATOR_VERSION="${AWS_EMULATOR_VERSION:-1.0.341}"

echo "=== 1. Paquetes base (Debian repos oficiales) ==="
sudo apt-get update -qq
sudo apt-get install -y -qq curl jq git python3 python3-venv gpg ca-certificates \
  qemu-guest-agent docker.io unzip bc >/dev/null
# NOTA: docker-compose-v2 no existe como paquete en Debian 13; si hace falta compose
# en fases posteriores, usar el repo oficial de Docker (docker-compose-plugin).
sudo systemctl enable --now qemu-guest-agent docker
sudo usermod -aG docker "$USER" || true
echo "OK: curl/jq/git/python3/gpg/docker instalados"

echo "=== 2. AWS CLI v2 (install.sh oficial firmado — verificación fail-closed) ==="
if ! command -v aws >/dev/null; then
  T=$(mktemp -d)
  GNUPGHOME_TEMP="$(mktemp -d)"; chmod 700 "$GNUPGHOME_TEMP"
  export GNUPGHOME="$GNUPGHOME_TEMP"
  curl -fsSL "https://awscli.amazonaws.com/v2/install.sh" -o "$T/install.sh"
  curl -fsSL "https://awscli.amazonaws.com/v2/install.sh.sig" -o "$T/install.sh.sig"
  # Clave oficial AWS CLI Team — importada del keyserver; la verificación es
  # fail-closed: si el keyserver no está disponible, el fingerprint no cuadrará y aborta.
  gpg --keyserver keyserver.ubuntu.com --recv-keys A6310ACC4672475C 2>/dev/null
  EXPECTED_CLI_FP="FB5DB77FD5C118B80511ADA8A6310ACC4672475C"
  FP=$(gpg --fingerprint "AWS CLI Team" 2>/dev/null | grep -oE '[0-9A-F]{4}' | tr -d '\n ')
  [ "$FP" = "$EXPECTED_CLI_FP" ] || { echo "FATAL: fingerprint AWS CLI Team inesperado ('$FP')"; exit 1; }
  gpg --batch --status-file "$T/gpgstatus" --verify "$T/install.sh.sig" "$T/install.sh"
  grep -qE '^\[GNUPG:\] GOODSIG' "$T/gpgstatus" \
    || { echo "FATAL: firma del instalador AWS CLI no válida"; cat "$T/gpgstatus"; exit 1; }
  echo "Firma PGP del instalador AWS CLI: verificada (GOODSIG + fingerprint) ✓"
  sudo bash "$T/install.sh" --system
  rm -rf "$T" "$GNUPGHOME_TEMP"; unset GNUPGHOME
fi
aws --version

echo "=== 3. AWS Emulator $AWS_EMULATOR_VERSION: .deb oficial VERSIONADO con verificación fail-closed ==="
BASE="https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS"
# URLs versionadas oficiales (doc versioning.md): aws-emulator_<versión>-1_amd64.deb
PKG_FILE="aws-emulator_${AWS_EMULATOR_VERSION}-1_amd64.deb"
SIG_FILE="${PKG_FILE}.sig"
if ! command -v aws-emulator >/dev/null; then
  T=$(mktemp -d)
  GNUPGHOME_TEMP="$(mktemp -d)"; chmod 700 "$GNUPGHOME_TEMP"; export GNUPGHOME="$GNUPGHOME_TEMP"
  curl -fsSLo "$T/$PKG_FILE" "$BASE/$PKG_FILE" \
    || { echo "FATAL: no existe la versión ${AWS_EMULATOR_VERSION} (ver versions.json): $BASE/$PKG_FILE"; exit 1; }
  curl -fsSLo "$T/$SIG_FILE" "$BASE/$SIG_FILE"
  curl -fsSLo "$T/aws-publishing.asc" "https://downloads.aws.com/keys/gpg/current.asc"
  gpg --import "$T/aws-publishing.asc" 2>/dev/null
  EXPECTED_EMU_FP="98BCF336A3BE53B734E967C52E5BF49BD940F624"
  FP=$(gpg --fingerprint ssm-publishing@amazon.com 2>/dev/null | grep -oE '[0-9A-F]{4}' | tr -d '\n ')
  [ "$FP" = "$EXPECTED_EMU_FP" ] || { echo "FATAL: fingerprint inesperado ('$FP')"; exit 1; }
  gpg --batch --status-file "$T/gpgstatus" --verify "$T/$SIG_FILE" "$T/$PKG_FILE"
  grep -qE '^\[GNUPG:\] GOODSIG' "$T/gpgstatus" \
    || { echo "FATAL: firma del paquete no válida"; cat "$T/gpgstatus"; exit 1; }
  echo "Firma GPG del emulador: verificada (GOODSIG + fingerprint) ✓"
  INSTALLED_VERSION=$(dpkg-deb -f "$T/$PKG_FILE" Version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  echo "versión del paquete descargado: $INSTALLED_VERSION"
  [ "$INSTALLED_VERSION" = "$AWS_EMULATOR_VERSION" ] \
    || { echo "FATAL: versión descargada ($INSTALLED_VERSION) ≠ requerida ($AWS_EMULATOR_VERSION). Abortando."; exit 1; }
  sudo apt-get install -y -qq "$T/$PKG_FILE" >/dev/null
  ACTUAL=$(aws-emulator -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  [ "$ACTUAL" = "$AWS_EMULATOR_VERSION" ] \
    || { echo "FATAL: versión instalada ($ACTUAL) ≠ requerida ($AWS_EMULATOR_VERSION). Abortando."; exit 1; }
  # Conservar copia local verificada + SHA-256 (reproducibilidad; no se sube a GitHub)
  ARCHIVE_DIR="$REPO_DIR/results/01-getting-started/artifacts"
  mkdir -p "$ARCHIVE_DIR"
  cp "$T/$PKG_FILE" "$ARCHIVE_DIR/$PKG_FILE"
  sha256sum "$T/$PKG_FILE" | awk '{print $1"  '"$PKG_FILE"'"}' \
    > "$ARCHIVE_DIR/$PKG_FILE.sha256"
  echo "copia verificada + SHA-256 en $ARCHIVE_DIR (fuera de Git: ver .gitignore)"
  rm -rf "$T" "$GNUPGHOME_TEMP"; unset GNUPGHOME
fi
aws-emulator -v

echo "=== 4. Python + dependencias fijadas (requirements.txt) en venv ==="
python3 -m venv "$REPO_DIR/.venv"
"$REPO_DIR/.venv/bin/pip" install --quiet --upgrade pip
"$REPO_DIR/.venv/bin/pip" install --quiet -r "$REPO_DIR/scripts/bootstrap/requirements-lock.txt"
"$REPO_DIR/.venv/bin/pip" freeze > "$REPO_DIR/scripts/bootstrap/requirements-frozen.txt"

echo "=== 5. Telemetría del emulador OFF ==="
mkdir -p "$HOME/.aws/emulator"
grep -q "telemetry enabled false" "$HOME/.aws/emulator/config.toml" 2>/dev/null \
  || echo 'telemetry enabled false' >> "$HOME/.aws/emulator/config.toml"
echo "OK: ~/.aws/emulator/config.toml"

echo "=== 6. Usuario de ejecución del emulador (privilegio mínimo) ==="
# Separación de privilegios: 'lab' administra; 'emu' ejecuta el emulador (sin sudo, sin docker)
if ! id emu >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash emu
  sudo mkdir -p /home/emu/.aws/emulator && sudo chown -R emu:emu /home/emu/.aws
  echo 'telemetry enabled false' | sudo tee /home/emu/.aws/emulator/config.toml >/dev/null
fi
echo "OK: usuario 'emu' disponible (sudo -u emu aws-emulator ...)"

echo "=== Bootstrap completo. Versiones instaladas: ==="
echo " - $(aws --version 2>&1)"
echo " - $(aws-emulator -v 2>&1)"
echo " - boto3: $("$REPO_DIR/.venv/bin/pip" show boto3 | grep -E '^Version')"
echo " - $(docker --version) · $(git --version) · $(python3 --version)"
