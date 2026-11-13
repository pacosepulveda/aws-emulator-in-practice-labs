# Notas de licencias

## Código original del repositorio

**Apache License 2.0** (ver [LICENSE](../LICENSE)). Copyright 2026 Francisco Sepúlveda.

**Alcance:** el código de este repositorio (scripts, tests, Dockerfile, Makefile).
Los artículos completos del blog, materiales de cursos y futuros materiales
comerciales están **fuera** del alcance de esta licencia; la licencia de la
documentación didáctica se decidirá más adelante.

## Componentes de terceros

| Software | Licencia | Uso |
|---|---|---|
| aws/aws-emulator | CC0-1.0 (carpeta vendor/: Apache-2.0) | Sujeto de estudio |
| AWS CLI v2 | Apache-2.0 | Cliente de pruebas |
| Boto3/botocore | Apache-2.0 | SDK de pruebas |
| Docker Engine / Moby | Apache-2.0 | Experimento E |
| Debian 13 / Amazon Linux 2023 | Varias | SO base de la VM / del contenedor |
| LocalStack (fase 2) | Propietario (Community: funcionalidad limitada; Pro: comercial) | Sujeto de comparativa — pendiente revisión de términos |

## Paquete del emulador (downloads.aws.com)

El paquete oficial se descarga y verifica según los términos de distribución
publicados por AWS. Conservamos una copia local con su SHA-256 para
reproducibilidad; **no se distribuye a través de este repositorio**.
