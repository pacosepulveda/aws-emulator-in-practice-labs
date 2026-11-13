# Informe de resultados — Lab 01 (instalación y primeros pasos) — v2 revisado

**Fecha:** 2026-11-13 (UTC) · **Emulador:** v1.0.341 · **VM:** aws-emulator-lab (Debian 13, CPU host)
**Totales (generados automáticamente desde los registros — `make stats`):**
**40 pruebas funcionales: 35 PASS · 4 FAIL · 1 PARTIAL · 0 UNSUPPORTED** + **1 observación documental**
(JSON: [results.json](results.json) · logs completos en `logs/` (fuera de Git); selección sanitizada en `logs-public/`)

> Metodología: los FAIL históricos (v1) se conservan como evidencia didáctica con su
> causa raíz documentada. Los totales los genera `scripts/common/gen_stats.py` desde
> los registros individuales; OBSERVADO se contabiliza aparte de las pruebas funcionales.
> Informe original de primera versión: [report-fase1-original.md](report-fase1-original.md)

## Experimento A — Instalación nativa y arranque

| Prueba | Resultado | Notas |
|---|---|---|
| Verificación GPG del .deb (fingerprint AWS) | PASS | Good signature de SSM Publishing |
| Arranque (proceso→health) | PASS | **0,6 s mediana** en 3 repeticiones (0,56–0,59) |
| Health `__admin/health` | PASS | respuesta `ok` sobre HTTPS |
| Ficheros `~/.aws/emulator/9297/` | PASS | ca.pem, config, emulator_credentials, truststore.p12 |
| RAM en reposo | PARTIAL→aclarado | **RSS 286 MiB / PSS 284 MiB** (mediana 3 reps, estable t0 y t+30s); la doc afirma ~160 MiB. Registrado como dato observado de medición, **no clasificado como fallo funcional** |

Mediciones detalladas: `perf_*.json` (RSS y PSS en arranque, reposo 30 s, tras batería
306,6 MiB; batería 10× `s3 ls` 9,7 s mediana; Docker medido dentro del exp. E).

## Experimento B — AWS CLI (v2)

B1 round-trip objeto · B2 **versionado: 2 versiones + 1 delete marker** ·
B3 cifrado+BPA (representación) · B4 DynamoDB con espera ACTIVE · B5 SQS íntegro:
**5/5 PASS**, exit 0, run_id único, limpieza con trap que incluye versiones y delete markers.

## Experimento C — Python + Boto3 (v2)

C1–C6 **6/6 PASS** en nativo y también contra el contenedor Docker.
Latencias: STS 0,00 s · create_bucket 0,01 s · round-trip 0,27 s · SQS 0,05 s.

## Experimento D — Persistencia y reinicio

- SIGTERM detiene el proceso y **borra todos los recursos** → coincide con la doc.
- Credenciales y certificados regenerados en cada arranque.
- Multi-instancia (9297+9298): aislamiento total de recursos (PASS).

## Experimento E — Docker (v2, según doc oficial)

La doc oficial (`getting-started-docker.html`) **exige `-b 0.0.0.0` dentro del
contenedor** para que Docker pueda redirigir el puerto; el Dockerfile inicial (v0)
no la incluía y por eso fallaba el port publishing. **No es una limitación del
emulador.** El intento v0 se conserva como evidencia didáctica
(`docker/Dockerfile.initial-failed`).

**Dockerfile v2** (doc oficial + endurecimientos propios):
- Base `amazonlinux:2023-minimal`, paquete RPM oficial, **verificación fail-closed
  con rpmkeys/rpm -K** (sin gpg-agent — AL2023-minimal no lo incluye), usuario 1000,
  `-b 0.0.0.0` en ENTRYPOINT, telemetría OFF.
- Ejecución: red **bridge** con `-p 127.0.0.1:$PORT:$PORT`, volumen `~/.aws/emulator`,
  `--user "$(id -u):$(id -g)"` (procedimiento Linux de la doc).

**Resultados v2: 9/9 PASS** — build, health HTTPS, STS, S3, DynamoDB, SQS, Boto3
completo, aislamiento LAN (bind 127.0.0.1 verificado), coexistencia con instancia
nativa, propiedad de cert/creds.

Hallazgos durante el trabajo Docker (documentados, no atribuidos sin evidencia):
1. **CPU del hypervisor:** AL2023 requiere x86-64-v2; el tipo de CPU por defecto de
   el hypervisor (qemu64) no lo soporta → VM cambiada a `--cpu host`. Sin esto el
   contenedor abortaba con `Fatal glibc error: CPU does not support x86-64-v2`.
2. **gnupg:** AL2023-minimal trae `gnupg2-minimal` **sin gpg-agent** → `gpg --verify`
   no funciona dentro del build. Sustituido por verificación con keyring de rpm
   (`rpmkeys --import` + `rpm -K`): fail-closed, sin dependencia de texto localizado.
3. **Nombres de bucket con mayúsculas** (run_id en formato ISO) → rechazados con
   `InvalidBucketName`, igual que AWS real. Corregido el generador de run_ids
   (punto a favor de la fidelidad del emulador).

## Pruebas negativas de seguridad (controles anti-AWS-real)

**4/4 PASS**: el script de Boto3 **aborta sin ejecutar operaciones** con endpoint
AWS real, endpoint local sin TLS, endpoint ausente y endpoint no-local. Validación
por parsing de URL, scrub de variables AWS/proxy, credenciales explícitas del
emulador y precondición STS con cuenta esperada `000000000000`.

## Problemas encontrados y soluciones

1. **AWS CLI zip 404 desde nuestra VM en la fecha del test** (AWS CLI sigue
   documentando ambos métodos y recomienda `install.sh`; el 404 observado no
   demuestra retirada del método zip). Usado `install.sh` con verificación PGP
   fail-closed (fingerprint + GOODSIG legible por máquina, keyring aislado).
2. **Fichero de firma:** `aws-emulator_amd64.deb.sig` (incluye arquitectura).
3. **403 transitorios de downloads.aws.com** repitiendo descargas grandes
   (incidencia observada; causa no determinada). Reintentos con espera.
4. **`docker-compose-v2` no existe como paquete en Debian 13** — no necesario en esta fase.
5. **Carrera DynamoDB en tests v1** (put sin esperar ACTIVE) → waiters en B y C.
6. **Guards de scripts:** health-check por puerto y validación de PID (cmdline de
   /proc) en stop.sh — nunca detiene instancias de otros puertos ni procesos ajenos.

## Pendientes / limitaciones

- Divergencia de medición de RAM (286 vs ~160 MiB) documentada como observación.
- Fidelidad de controles de seguridad NO probada (artículo 03).
- La URL pública del paquete apunta a "LTS/latest": fijamos v1.0.341 con SHA-256
  local (`results/artifacts/`, fuera de Git) y versionado vía ARG en el Dockerfile.
- `scores.json.gz` de fidelidad aún sin analizar (candidato a artículo).

## Reproducir

```bash
# en la VM aws-emulator-lab, usuario lab:
cd aws-emulator-in-practice
make setup && make start
make test-native            # B + C + D
make test-docker            # E v2 (bridge + localhost)
make test-selftest          # pruebas negativas
make perf                   # mediciones (REPS=n)
make stats                  # totales desde registros
make stop
```
