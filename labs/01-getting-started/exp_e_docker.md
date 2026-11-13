# Experimento E — AWS Emulator en Docker (procedimiento final validado)

> v2.1 (2026-11-13): sustituye a las instrucciones preliminares. El procedimiento
> validado usa **paquete RPM versionado**, **verificación de firma en el keyring
> rpm**, **red bridge con publicación solo en localhost**, **TLS con la CA del
> emulador** y **usuario no root**. El primer intento fallido (v0) se conserva en
> [Dockerfile.initial-failed](Dockerfile.initial-failed) como evidencia didáctica.

## Contexto

- **No existe imagen oficial publicada** en un registry (verificado en ECR/Docker Hub).
- La documentación oficial propone **construir un contenedor desde un Dockerfile**
  ([Getting started with Docker](https://docs.aws.amazon.com/emulator/latest/userguide/getting-started-docker.html)).
- La doc oficial exige **`-b 0.0.0.0`** dentro del contenedor: el emulador escucha en
  `127.0.0.1` por defecto y sin esa opción el port publishing falla (causa del fallo v0).

## El Dockerfile validado (`docker/Dockerfile`)

- Base `public.ecr.aws/amazonlinux/amazonlinux:2023-minimal` (requiere CPU x86-64-v2)
- Paquete **versionado** por URL oficial (doc versioning.md):
  `https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/aws-emulator-<versión>-1-x86_64.rpm`
- Verificación **fail-closed sin gpg-agent**: `rpmkeys --import` (solo la clave AWS,
  fingerprint `98BCF336A3BE53B734E967C52E5BF49BD940F624`, key ID `d940f624`) + `rpm -K`
  exige `digests signatures OK`; aborta si la clave importada no es la esperada
- `USER 1000` (no root), telemetría OFF, `ENTRYPOINT aws-emulator -b 0.0.0.0`

## Procedimiento

```bash
cd labs/01-getting-started/docker/
docker build -t aws-emulator:local .        # ARG EMU_VERSION=1.0.341 por defecto

# ejecución validada: bridge + SOLO localhost + volumen de credenciales + no root
docker run -d --name aws-emulator-e \
  --user "$(id -u):$(id -g)" \
  -e HOME="$HOME" -v "$HOME/.aws/emulator:$HOME/.aws/emulator" \
  -p 127.0.0.1:9298:9298 \
  aws-emulator:local -p 9298 -t off

# health check (TLS con la CA generada por el emulador en el volumen)
curl -sf --cacert ~/.aws/emulator/9298/ca.pem https://127.0.0.1:9298/__admin/health
```

Las credenciales y certificados los genera el propio emulador en
`~/.aws/emulator/<puerto>/` (volumen compartido, propiedad del usuario gracias a
`--user uid:gid`); **no se necesita `docker cp`**.

## Batería automatizada (`exp_e_docker.sh`, 12 verificaciones)

1. Build con verificación RPM fail-closed
2. Health HTTPS sobre bridge con publicación en 127.0.0.1 (aborta si agota intentos)
3. Guard STS del contenedor (cuenta `000000000000`)
4. S3 create / 5. S3 put+list (endpoint explícito del contenedor)
6. DynamoDB create (wait implícito)
7. SQS create
8. Boto3 completo (`exp_c_boto3.py`) contra el contenedor
9. Aislamiento LAN (bind local = 127.0.0.1 verificado con `ss`)
10. Coexistencia con la instancia nativa 9297 — **la nativa se opera siempre con
   endpoint/credenciales explícitos y guard STS propio** (nunca configuración por defecto)
11. Aislamiento de recursos nativo/contenedor
12. Propiedad de cert/creds (`--user`)

Resultado de referencia: **9/9 PASS** (batería E-v2) y 12/12 con los guard STS de v2.1.
Fallos de operaciones obligatorias se contabilizan como FAIL y el script termina con
código de salida no cero.

## Diferencias nativo vs contenedor (verificadas)

- Latencia adicional por el bridge (marginal en operaciones simples)
- El contenedor replica el mismo comportamiento de estado en memoria
- La telemetría se desactiva con `-t off` en el comando del contenedor
