# AWS Emulator in Docker — procedimiento oficial de AWS
# https://docs.aws.amazon.com/emulator/latest/userguide/getting-started-docker.html
# Mejoras propias (documentadas): paquete VERSIONADO (URL oficial de versioning.md),
# verificación fail-closed del keyring RPM (key ID de la clave de AWS) y telemetría OFF.
#
# NOTA v0 (Dockerfile.initial-failed): nuestro primer intento usaba otra base sin
# -b 0.0.0.0; el port publishing fallaba porque el emulador escucha en 127.0.0.1
# dentro del contenedor. La doc oficial exige -b 0.0.0.0 para Docker.
# Se conserva como evidencia didáctica.
FROM public.ecr.aws/amazonlinux/amazonlinux:2023-minimal

# Versión de referencia del laboratorio; URL versionada oficial (doc versioning.md):
# https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/aws-emulator-<versión>-1-x86_64.rpm
# Para actualizar: cambia EMU_VERSION por una versión de LTS/versions.json y
# registra la nueva versión + SHA-256 en results/.
ARG EMU_VERSION=1.0.341

ADD https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/aws-emulator-${EMU_VERSION}-1-x86_64.rpm /tmp/aws-emulator.rpm
ADD https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/aws-emulator-${EMU_VERSION}-1-x86_64.rpm.sig /tmp/aws-emulator.rpm.sig
ADD https://downloads.aws.com/keys/gpg/current.asc /tmp/aws-publishing.asc

# Verificación fail-closed con el keyring de rpm (AL2023-minimal no trae gpg-agent):
#  1) rpmkeys importa SOLO la clave de AWS (SSM Publishing, fingerprint
#     98BCF336A3BE53B734E967C52E5BF49BD940F624, key ID corto D940F624)
#  2) comprobamos que la clave importada es exactamente esa (gpg-pubkey-d940f624)
#  3) rpm -K solo da "digests signatures OK" si el paquete está firmado por una
#     clave del keyring — al haber solo la de AWS, OK ⇒ firmado por AWS
RUN set -eu; \
    rpmkeys --import /tmp/aws-publishing.asc; \
    rpm -q gpg-pubkey-d940f624 >/dev/null \
      || { echo "FATAL: la clave importada no es la esperada (gpg-pubkey-d940f624 / fingerprint 98BCF336A3BE53B734E967C52E5BF49BD940F624)"; rpm -q gpg-pubkey; exit 1; }; \
    RESULT=$(rpm -K /tmp/aws-emulator.rpm); \
    echo "$RESULT"; \
    case "$RESULT" in *digests\ signatures\ OK*) ;; *) echo "FATAL: verificación RPM fallida"; exit 1;; esac; \
    rpm -i /tmp/aws-emulator.rpm; \
    rm -rf /tmp/aws-emulator.rpm /tmp/aws-emulator.rpm.sig /tmp/aws-publishing.asc; \
    mkdir -p /home/emulator && chown 1000 /home/emulator

USER 1000
ENV HOME=/home/emulator
ENV EMULATOR_TELEMETRY=off
EXPOSE 9297
# -b 0.0.0.0: requisito OFICIAL para Docker (doc getting-started-docker). La
# exposición real se controla en docker run con -p 127.0.0.1:PORT:PORT.
ENTRYPOINT ["aws-emulator", "-b", "0.0.0.0"]
