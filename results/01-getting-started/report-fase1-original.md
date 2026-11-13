# Informe de resultados — Lab 01 (instalación y primeros pasos)

**Fecha:** 2026-11-13 · **Emulador:** v1.0.341 · **VM:** aws-emulator-lab (Debian 13)
**Resumen:** 24 PASS · 1 FAIL · 1 PARTIAL · 1 OBSERVADO · 0 UNSUPPORTED
(JSON estructurado: [results.json](results.json) · logs en `logs/`)

## Experimento A — Instalación nativa y arranque

| Prueba | Resultado | Notas |
|---|---|---|
| Verificación GPG del .deb (fingerprint AWS) | PASS | Good signature de SSM Publishing |
| Arranque hasta health OK | PASS | **1,09 s** medidos (script completo) |
| Health `__admin/health` | PASS | respuesta `ok` sobre HTTPS |
| Ficheros `~/.aws/emulator/9297/` | PASS | ca.pem, config, emulator_credentials, truststore.p12 |
| RAM en reposo | **PARTIAL** | medido **286,4 MiB**; doc afirma ~160 MiB (re-medir en entorno más limpio) |

## Experimento B — AWS CLI (STS/S3/DynamoDB/SQS)

B1 STS · B2 create-bucket · B3 objeto round-trip · B4 versionado · B5 cifrado+BPA ·
B7 SQS · B8 limpieza: **PASS**. B6 DynamoDB: PASS tras corregir el test (ver abajo).

## Experimento C — Python + Boto3

C1–C6 **PASS** (6/6). Latencias: STS 0,01 s · create_bucket 0,05 s · objeto 0,02 s ·
SQS 0,03 s. DynamoDB 3,02 s (incluye espera a ACTIVE — ver incidencia).

## Experimento D — Persistencia y reinicio

- SIGTERM detiene el proceso y **borra todos los recursos** (bucket y tabla marcadores
  desaparecen tras reinicio limpio) → **coincide con la doc oficial** (estado solo en memoria).
- Credenciales y certificados: regenerados en cada arranque (los ficheros se recrean).
- **Multi-instancia:** 9297 y 9298 con aislamiento total de recursos (PASS).

## Experimento E — Docker

- **No existe imagen oficial** (OBSERVADO): la doc propone Dockerfile propio →
  implementado reproducible con verificación GPG en `labs/01-getting-started/docker/Dockerfile`
  (imagen `aws-emulator:local`, digest `ea561f1ff256…`).
- **FAIL relevante:** `docker run -p 9298:9297` NO funciona — el emulador escucha en
  `127.0.0.1` dentro del contenedor y el port-publishing nunca alcanza el servicio
  (síntoma: TLS `unexpected eof`). **Solución validada: `--network host`.**
- Con `--network host`: STS/S3/SQS PASS. Telemetría OFF confirmada en logs del contenedor.

## Problemas encontrados y soluciones

1. **La URL clásica del zip de AWS CLI devolvió 404 desde nuestra VM en la fecha del test (AWS CLI sigue documentando ambos métodos y recomienda install.sh — el 404 no demuestra retirada). Método utilizado:
   `install.sh` firmado (PGP verificado) → CLI 2.40.2 instalada.
2. **Nombre del fichero de firma:** `aws-emulator_amd64.deb.sig` (la doc usa patrón
   `$PACKAGE_FILE.sig`; con el nombre sin arquitectura da 403/404).
3. **403 transitorios de downloads.aws.com (causa no determinada: posible limitación de peticiones repetidas, sin evidencia suficiente para atribuirla)** al repetir descargas grandes — reintentos.
4. **`docker-compose-v2` no existe en Debian 13** (paquete de cloud-init) — irrelevante
   para esta fase; usar repo oficial Docker si hace falta compose.
5. **Carrera DynamoDB en los tests:** PutItem inmediato tras CreateTable →
   `ResourceNotFoundException` (la tabla aún no está ACTIVE). El emulador replica la
   exigencia de AWS real; los tests ahora esperan ACTIVE (waiter).
6. **Guards de scripts:** `pgrep -f` matcheaba el propio wrapper SSH → sustituido por
   health-check por puerto.

## Pendientes / limitaciones detectadas

- RAM en reposo diverge de la doc (286 vs 160 MiB) — re-medir tras arranque limpio.
- Fidelidad de controles de seguridad NO probada (B5 solo demuestra que la
  configuración se almacena y devuelve — artículo 03 lo abordará).
- Fidelity scores (`scores.json.gz`) aún sin analizar — candidato a artículo extra.

## Reproducir

```bash
# en la VM aws-emulator-lab (<IP-LAN>), usuario lab:
cd ~/aws-emulator-in-practice
make setup && make start && make test && make stop
```
