# Ficha editorial — Artículo 01 (material de apoyo, no es el artículo)

## Hallazgos técnicos más interesantes (para el gancho y el cuerpo)

1. **AWS tiene su propio emulador oficial desde nov-2026** (repo sep-2026, lanzamiento
   público 11-nov-2026): Rust, un crate por servicio, fidelidad medida y publicada
   en cada release, licencia CC0-1.0. Hasta ahora este nicho era de LocalStack.
2. **El estado es solo-en-memoria y lo comprobamos**: SIGTERM borra buckets y tablas
   verificados con marcadores (no lo asumimos por la doc).
3. **Arranque de 0,6 s** y 286 MiB RSS medidos con metodología reproducible
   (3 reps, mediana/min/max) — la doc afirma ~160 MiB; divergencia documentada como
   observación.
4. **Docker tiene truco**: sin `-b 0.0.0.0` el port publishing nunca funciona porque
   el emulador escucha en 127.0.0.1 dentro del contenedor. Falla con un "TLS
   unexpected eof" críptico. Nuestro primer intento falló por esto — narrativa ideal.
5. **La firma del paquete se verifica con el keyring de rpm** (rpmkeys + rpm -K):
   AL2023-minimal no trae gpg-agent y gnupg2-minimal entra en conflicto con gnupg2 —
   camino no documentado que resolvimos de forma fail-closed.
6. **El emulador replica comportamientos de AWS real que rompen tests ingenuos**:
   exige esperar ACTIVE en DynamoDB y valida nombres de bucket (mayúsculas →
   InvalidBucketName). Punto a favor de su fidelidad.
7. **Controles anti-AWS-real verificables**: precondición STS con cuenta
   000000000000 + 6 pruebas negativas (endpoint AWS real, sin TLS, no-local,
   identidad incorrecta, credenciales inválidas) — todos los guards abortan.
8. **CPU del hypervisor importa**: AL2023 exige x86-64-v2; el tipo qemu64 por defecto no
   basta → `--cpu host` o el contenedor aborta con `Fatal glibc error`.

## Comandos imprescindibles para reproducir

```bash
# setup completo (instala y verifica: emulador GPG, CLI PGP, boto3 fijado)
make setup
make start                      # emulador en https://127.0.0.1:9297, telemetría off
source scripts/common/env.sh 9297   # credenciales del emulador + guard STS

make test-cli          # B: STS/S3/DynamoDB/SQS con AWS CLI
make test-sdk          # C: Boto3 (aborta si el endpoint no es local válido)
make test-persistence  # D: SIGTERM borra estado; multi-instancia
make test-docker       # E: bridge + -p 127.0.0.1:PORT:PORT, no-root, negativa RPM
make test-selftest     # pruebas negativas de los controles
make perf              # RSS/PSS/arranque (3 reps, mediana)
make stats             # totales desde los registros individuales
make clean             # SOLO recursos aws-emulator-lab-*
make stop
```

## Resultados de la versión de referencia (v1.0.341 · CLI 2.40.2 · Boto3 1.44.2 · Docker 29.9.3)

- **33/33 PASS** en la ejecución de referencia (results.json, generado automáticamente)
- 10 incidencias históricas separadas en results-historial.json (todas resueltas)
- 40 pruebas acumuladas del proyecto: 35 PASS / 4 FAIL históricos / 1 PARTIAL aclarado

## Limitaciones que SÍ hemos comprobado

- Estado solo-en-memoria (SIGTERM borra todo).
- Sin imagen Docker oficial → Dockerfile propio con `-b 0.0.0.0`.
- Exigencia de espera ACTIVE en DynamoDB; validación estricta de bucket names.
- RAM en reposo medida 286 MiB ≠ ~160 MiB documentados (divergencia, no fallo).
- Escucha en 127.0.0.1 por defecto (pivota el diseño de red en Docker).

## Limitaciones conocidas SOLO por documentación oficial

- "No usar para probar seguridad": emular configuración ≠ aplicar controles
  (pendiente de verificación experimental en el artículo 03).
- Cobertura/fidelidad por servicio según scores.json.gz de cada release (pendiente).
- Aislamiento de código Lambda sin fronteras reales (se probará en art. 05).

## Errores encontrados → causa → solución (resumen para la sección "problemas")

| Error | Causa | Solución |
|---|---|---|
| PutItem → ResourceNotFound | tabla aún no ACTIVE (race del test) | waiters |
| TLS unexpected eof en Docker | escucha 127.0.0.1 dentro del contenedor | `-b 0.0.0.0` (doc oficial) |
| Fatal glibc error x86-64-v2 | CPU qemu64 del hypervisor | `--cpu host` |
| gpg-agent: Configuration error | AL2023-minimal sin agente | rpmkeys/rpm -K |
| InvalidBucketName | run_id con mayúsculas | run_id lowercase |
| 404 zip AWS CLI | AWS cambió distribución (zip sigue documentado) | install.sh firmado PGP |
| 403 intermitente downloads.aws.com | causa no determinada (repetición de descargas grandes) | reintentos |
| guards de scripts falsos positivos | pgrep -f matchea el propio ssh | health-check + pidfile /proc |

## Evidencias listas para el artículo

- `logs-public/captura-sts.md` — get-caller-identity con cuenta 000000000000
- `logs-public/captura-docker-build.md` — verificación RPM + health
- `logs-public/captura-guard-sts.md` — FATAL con identidad incorrecta
- `logs-public/emulator-arranque-sanitizado.txt`, `exp_b_aws_cli-sanitizado.txt`
