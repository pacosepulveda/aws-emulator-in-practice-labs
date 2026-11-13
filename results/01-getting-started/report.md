# Informe de referencia final — Lab 01 (instalación y primeros pasos)

**Fecha:** 2026-11-13 (UTC) · **Emulador:** v1.0.341 · **VM:** aws-emulator-lab (Debian 13, `--cpu host`)
**Docker:** 29.9.3 (repo oficial; actualizado desde 26.1.5 por el aviso L2 de versiones <28)

## Resultados de la ejecución de referencia

**33/33 PASS** (generados automáticamente desde [results.json](results.json) — `make stats`).
Los fallos de iteraciones anteriores están **separados** en
[results-historial.json](results-historial.json) (10 incidencias, todas resueltas) y no
forman parte de esta referencia. El historial completo narrativo está en
[report-historial-completo.md](report-historial-completo.md).

| Experimento | Cobertura | Resultado |
|---|---|---|
| A — instalación/arranque | GPG, arranque, health, ficheros, RAM (RSS/PSS) | 4/4 PASS |
| B — AWS CLI | S3 round-trip, versionado+delete markers, cifrado/BPA (representación), DynamoDB, SQS | 5/5 PASS |
| C — Boto3 nativo | STS, S3, DynamoDB (waiter), SQS, delete | 6/6 PASS |
| D — persistencia | SIGTERM borra estado, credenciales regeneradas, multi-instancia | 3/3 PASS |
| E — Docker (bridge) | build verificado, `-p 127.0.0.1:`, S3/DDB/SQS/Boto3, aislamiento LAN verificado desde otra máquina, no-root, negativa criptográfica | 9/9 PASS |
| SEG — controles | 4 self-tests + identidad incorrecta + credenciales inválidas | 6/6 PASS |

## Datos clave de la versión de referencia

- **Arranque (proceso→health):** 0,60 s mediana (3 reps, 0,56–0,59) — ver [metodología](metodologia-medicion.md)
- **RAM en reposo:** RSS 286 MiB / PSS 284 MiB (mediana 3 reps, estable t0 y t+30s); tras batería 306,6 MiB
- **Latencias:** STS 0,00 s · create_bucket 0,01 s · round-trip S3 0,27 s · SQS 0,05 s
- **Batería 10× `s3 ls`:** 9,7 s mediana
- **Estado tras SIGTERM:** se borra todo (coincide con la doc); credenciales regeneradas por arranque
- **Cuenta emulada:** 000000000000, SigV4, endpoint único HTTPS localhost:9297

## Limitaciones COMPROBADAS en este laboratorio

1. Estado solo-en-memoria: SIGTERM borra recursos (verificado con marcadores).
2. No hay imagen Docker oficial: Dockerfile propio (el oficial de AWS como base).
3. Nombres de bucket: validación igual que AWS real (mayúsculas rechazadas).
4. DynamoDB exige esperar ACTIVE antes de escribir (igual que AWS real).
5. El emulador escucha en 127.0.0.1 por defecto → `-b 0.0.0.0` imprescindible en Docker.
6. RAM en reposo medida (286 MiB) difiere de la cifra documental (~160 MiB).

## Limitaciones conocidas SOLO por documentación oficial (sin probar aquí)

- No usar para validar seguridad/pentesting/compliance (AWS lo advierte expresamente).
- Cobertura y fidelidad por servicio según el release `scores.json.gz` (pendiente de análisis).
- ~160 MiB de RAM en reposo (nuestra medición difiere; metodologías distintas).
- Aislamiento de código Lambda: la doc advierte que el código se ejecuta sin
  fronteras de seguridad reales (se verificará en el artículo 05).

## Evidencias

- Logs completos: `logs/` (fuera de Git) · **sanitizados: [logs-public/](logs-public/)**
- Medición detallada: `perf_*.json` · JSON estructurado: [results.json](results.json)
- Capturas de terminal para el artículo: `logs-public/captura-*.md`
