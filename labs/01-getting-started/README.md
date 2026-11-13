# Lab 01 — Instalación y primeros pasos con AWS Emulator

Objetivo: instalar el emulador (nativo y Docker), verificar su comportamiento
con AWS CLI y Boto3 (S3, DynamoDB, SQS, STS), medir arranque/recursos y
documentar persistencia y limitaciones observadas.

## Experimentos

| ID  | Título | Script/Procedimiento |
|-----|--------|----------------------|
| A   | Instalación nativa y arranque | `scripts/bootstrap/install-deps.sh` + `scripts/emulator/start.sh` |
| B   | AWS CLI: STS/S3/DynamoDB/SQS | `labs/01-getting-started/exp_b_aws_cli.sh` |
| C   | Python + Boto3 | `labs/01-getting-started/exp_c_boto3.py` |
| D   | Persistencia y reinicio | `labs/01-getting-started/exp_d_persistence.sh` |
| E   | Instalación en Docker | `labs/01-getting-started/exp_e_docker.md` + Dockerfile |

## Requisitos

- VM Debian 13 (2 vCPU / 4 GB / 30 GB), usuario `lab` sin privilegios
- Docker solo para el experimento E
- Sin credenciales AWS reales en la máquina

## Ejecución

```bash
make setup && make start && make test
```

Los resultados se escriben en `results/01-getting-started/` (report.md + results.json).

## Nomenclatura de recursos

Todos los recursos creados por este laboratorio usan el prefijo `aws-emulator-lab-01-`
para que `make clean` pueda eliminarlos de forma explícita y limitada.
