# Experimento E — Instalación mediante Docker

## Estado oficial (verificado 2026-11-13)

- **No existe imagen oficial publicada** en un registry (no se encontró en ECR/Docker Hub bajo la org aws).
- La documentación oficial propone **construir un contenedor desde un Dockerfile corto**
  ([Getting started with Docker](https://docs.aws.amazon.com/emulator/latest/userguide/getting-started-docker.html)).
- El paquete base es el `.deb`/`.rpm` oficial de `downloads.aws.com`.

## Procedimiento

```bash
cd labs/01-getting-started/docker/
cp ../../scripts/bootstrap/install-deps.sh .   # referencia
docker build -t aws-emulator:local .
docker run -d --name aws-emulator-e -p 9297:9297 aws-emulator:local
docker logs aws-emulator-e | head -5
```

El Dockerfile instala el .deb con verificación GPG dentro de la imagen
(contruible, reproducible; el digest del build se registra en results/).

## Pruebas a repetir en el contenedor

Subconjunto representativo del experimento B: STS, S3 round-trip, DynamoDB, SQS
(con las env vars apuntando al contenedor; `ca.pem` sale del contenedor vía
`docker cp` para el `AWS_CA_BUNDLE` del host).

## Diferencias esperadas (a verificar)

- Rendimiento con overlay de red extra (latencia por Docker bridge)
- Reinicio del contenedor vs reinicio del proceso nativo (persistencia)
- La telemetría debe desactivarse también dentro del contenedor (`--telemetry off` / env)
