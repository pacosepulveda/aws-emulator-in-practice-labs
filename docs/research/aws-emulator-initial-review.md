# Investigación inicial — AWS Emulator (Fase 1)

**Fecha de consulta:** 2026-11-13 · **Investigador:**  (agente de Francisco)

## 1. Qué es

AWS Emulator es el emulador **oficial** de las APIs de AWS, publicado por AWS.
Permite probar software contra un endpoint local con APIs compatibles con AWS,
sin cuenta AWS y sin coste adicional.

## 2. Ficha del repositorio

| Campo | Valor | Fuente |
|---|---|---|
| URL | https://github.com/aws/aws-emulator | GitHub API, 2026-11-13 |
| Creado | 2026-09-11 | GitHub API |
| Última release al iniciar | **v1.0.341** (2026-11-13) | GitHub API |
| Cadencia | releases diarios (338-341 en 2 días) | GitHub API |
| Lenguaje | Rust (workspace: un crate por servicio) | README |
| Licencia | **CC0-1.0** (vendor/ bajo Apache-2.0) | README/LICENSE |
| Stars | ~5.851 (API) / 91 (web en la lectura) | GitHub API |
| Suite de evaluación | https://github.com/aws/aws-emulator-evaluation-suite | GitHub API |
| Comunidad de issues de fidelidad | carpeta `issues/` del repo: `things-that-do-not-work/` | README |

## 3. Instalación oficial (Linux)

- Paquetes nativos **.deb/.rpm** en `https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/latest/`
- Firma GPG verificable: clave `https://downloads.aws.com/keys/gpg/current.asc`,
  fingerprint esperado `98BC F336 A3BE 53B7 34E9 67C5 2E5B F49B D940 F624`
- Instala en `/opt/aws-emulator/` y `/usr/bin/aws-emulator`
- Los releases de GitHub **no publican el binario** (solo `scores.json.gz` con
  puntuaciones de fidelidad): el binario se distribuye por downloads.aws.com

## 4. Arquitectura y operación (afirmado por AWS — a verificar en lab 01)

- Sirve **HTTPS en `127.0.0.1:9297`** (certificado autofirmado regenerado en cada arranque)
- **SigV4 obligatorio** por defecto (`--auth off` para desactivar; NO lo haremos)
- Genera credenciales propias en `~/.aws/emulator/<puerto>/` (emulator_credentials,
  config, ca.pem, truststore.p12) — válidas solo para esa ejecución
- Cuenta única: `000000000000`, identidad `arn:aws:iam::000000000000:user/emulator`
- Health check: `GET /__admin/health` → 200 "ok"
- **Estado solo en memoria** — SIGTERM borra recursos y ficheros (a verificar, Exp D)
- Consumo en reposo: ~160 MiB RAM
- Multi-instancia soportada (puertos distintos)
- Telemetría **ON por defecto** → desactivar con `-t off`, env `EMULATOR_TELEMETRY=off`
  o `~/.aws/emulator/config.toml` (`telemetry enabled false`)
- Sin interfaz gráfica; modos: server (CLI/SDK), embedded (Rust), contenedor
  (Dockerfile propio — **no hay imagen oficial publicada**)

## 5. Fidelidad

- AWS publica `scores.json.gz` con **fidelity scores por servicio** en cada release
- Los releases diarios son mayoritariamente `fix:` de divergencias con AWS real
  (v1.0.341: ~40 fixes; ejemplos: dynamodb PartiQL responses, s3 refusal fidelity,
  cloudformation drift detection) — señal de un proyecto en maduración activa
- Regla del proyecto: **nunca asumir** que una API funciona por estar documentada;
  clasificar: anunciada / implementada / validada por nuestra prueba / parcial / no soportada

## 6. Seguridad (afirmado por AWS — crítico para artículo 03)

- La doc oficial: **"Don't use it for production workloads or to test security"**
  (https://docs.aws.amazon.com/emulator/latest/userguide/security.html)
- El emulador genera credenciales propias; IAM/STS/policies emuladas pueden
  **representar** configuraciones sin **aplicar** los controles reales
- Implicación editorial: el emulador NO sustituye a AWS real para pentesting,
  validación de cumplimiento ni pruebas de seguridad — el artículo 03 está
  diseñado precisamente para medir esa brecha con experimentos

## 7. Requisitos (de la doc oficial)

- Instalación nativa Linux x86_64/amd64 o arm64; Windows/macOS solo contenedor
- Build desde fuente: Rust toolchain, compilador C, **~100 GB para target/**,
  máquina multinúcleo (NO aplicará a nuestro caso: usamos el paquete oficial)
- RAM en reposo ~160 MiB → nuestra VM de 4 GB sobrada

## 8. LocalStack (research superficial — comparativa completa en fase 2)

- Producto de terceros (LocalStack Pro/AWS) con edición Community gratuita y
  planes comerciales; amplio uso en pipelines CI
- **Pendiente fase 2:** versiones actuales, licencias exactas, cobertura, benchmarks
  (CPU/RAM/latencia), persistencia, compatibilidad IaC y controles de seguridad
- Diseño del lab: nuestras pruebas de lab 01 se escribirán para ser reutilizables
  contra LocalStack cambiando el endpoint (tests agnósticos del backend)

## 9. Fuentes (con fecha de consulta 2026-11-13)

1. https://github.com/aws/aws-emulator — README (instalación, arquitectura, telemetría)
2. https://github.com/aws/aws-emulator/releases — v1.0.341 y notas de fixes
3. https://docs.aws.amazon.com/emulator/latest/userguide/getting-started-linux.html — paquetes, GPG, operación
4. https://docs.aws.amazon.com/emulator/latest/userguide/point-sdk-to-emulator.html — env vars, credenciales, CA
5. https://docs.aws.amazon.com/emulator/latest/userguide/security.html — posición oficial sobre seguridad
6. https://github.com/aws/aws-emulator-evaluation-suite — suite de evaluación de fidelidad
