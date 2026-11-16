# Lab 01 — Getting started with AWS Emulator

> 📖 **También disponible en español:** [README.es.md](README.es.md)

Goal: install the AWS Emulator (native and Docker), verify its behaviour with
AWS CLI and Boto3 (S3, DynamoDB, SQS, STS), measure startup time and resource
usage, and document persistence and observed limitations.

**Reference result: 33/33 PASS** (plus a preserved history of 10 resolved
incidents, kept as didactic evidence). Full reports:
[`results/01-getting-started/`](../../results/01-getting-started/).

## Experiments

| ID | Title | Script / procedure |
|----|-------|--------------------|
| B | AWS CLI smoke test (STS / S3 / DynamoDB / SQS) | [`exp_b_aws_cli.sh`](exp_b_aws_cli.sh) |
| C | Boto3 SDK battery (aborts unless the endpoint is local) | [`exp_c_boto3.py`](exp_c_boto3.py) |
| D | Persistence: SIGTERM wipes memory-only state; multi-instance isolation | [`exp_d_persistence.sh`](exp_d_persistence.sh) |
| E | Docker: official procedure + bridge + localhost publishing + guards | [`exp_e_docker.sh`](exp_e_docker.sh) · [`exp_e_docker.md`](exp_e_docker.md) |

## Key results (reference run)

- Startup to health check: **0.60 s median** (3 runs, 0.56–0.59 s)
- Memory at rest: **286 MiB RSS** / 284 MiB PSS (stable)
- **State is memory-only**: SIGTERM removes all resources (verified with marker
  bucket/table, not assumed from docs)
- Multi-instance: fully isolated per port
- Docker: 9/9 checks, including L2 isolation from another LAN machine

## Safety model

Experiment scripts **abort by design** unless: the endpoint is a local HTTPS
endpoint, the STS identity matches the emulator's (`000000000000`), AWS
environment variables are scrubbed, explicit emulator credentials are used, and
the negative tests for every guard pass.

> ⚠️ The emulator emulates security configuration; it does **not** enforce it.
> We verified representation, never enforcement.

*Note: experiment scripts retain Spanish inline comments from the first run;
they are being adapted progressively under the repository language convention.*
