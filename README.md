# AWS Emulator in Practice

Hands-on, evidence-based testing of **AWS Emulator** — the official AWS emulator for
its API surface (open-sourced in September 2026, publicly launched November 11, 2026).

Every claim in this repository is backed by an executable experiment. Results are
machine-readable (`results/*/results.json`), statistics are generated from the
individual records (`scripts/common/gen_stats.py`), and failed historical attempts
are preserved — with root cause and fix — as didactic evidence.

> 📖 **Artículos y documentación en español:** [`docs/es/`](docs/es/)
> · Blog: [cloudsecurityinpractice.com](https://cloudsecurityinpractice.com)

## ⚠️ Security warnings

- **AWS does not recommend the emulator for security testing.** Emulating a security
  configuration (e.g. bucket encryption, Block Public Access) is NOT the same as
  enforcing it. We verified representation, not enforcement.
- The emulator listens on `127.0.0.1` by default. Keep it that way. In Docker you
  MUST pass `-b 0.0.0.0` *inside* the container (per AWS docs) and restrict
  exposure with `-p 127.0.0.1:$PORT:$PORT`.
- Our experiment scripts **abort by design** unless the endpoint is a local HTTPS
  endpoint and the STS identity matches the emulator's (`000000000000`), with AWS
  environment variables scrubbed, explicit credentials, and negative tests covering
  the guards.
- Packages are verified (GPG for the .deb, PGP for the AWS CLI installer, RPM
  keyring with only AWS's key — key ID `d940f624`, full fingerprint
  `98BCF336A3BE53B734E967C52E5BF49BD940F624`).

## Quick Start

Requirements: Debian 12/13 (or similar), `sudo`, internet access. **No AWS account,
no AWS credentials, no cloud resources.**

```bash
git clone https://github.com/pacosepulveda/aws-emulator-in-practice-labs.git
cd aws-emulator-in-practice-labs
make setup          # installs pinned versions: AWS CLI, AWS Emulator 1.0.341, boto3
make start          # starts the emulator on https://127.0.0.1:9297 (telemetry OFF)
make test-cli       # Experiment B: STS / S3 / DynamoDB / SQS with AWS CLI
make test-sdk       # Experiment C: Boto3 (aborts if the endpoint is not local)
make test-persistence  # Experiment D: SIGTERM wipes state; multi-instance isolation
make test-docker    # Experiment E: bridge network + localhost publishing
make stats          # totals generated from individual records
make stop           # SIGTERM — state is memory-only by design
make clean          # removes ONLY resources named aws-emulator-lab-*
```

## Labs and status

| Lab | Focus | Status | Results |
|---|---|---|---|
| 01 | Installation, first steps, Docker, persistence, security guards | ✅ complete | `results/01-getting-started/` |
| 02 | Infrastructure as Code (Terraform first; OpenTofu/CloudFormation/CDK later) | 🚧 in progress | `results/02-iac/` |

## Tested versions (reference run)

| Component | Version |
|---|---|
| AWS Emulator | 1.0.341 (versioned official URL, SHA-256 archived) |
| AWS CLI | 2.40.2 (install.sh, PGP-verified) |
| boto3 / botocore | 1.44.2 (locked) |
| Terraform | 1.13.3 (SHA-256) + `hashicorp/aws` provider 6.16.0 |
| Docker | 29.9.3 |
| OS | Debian 13 (host VM) · Amazon Linux 2023-minimal (container) |

## Key results (reference run — 33/33 PASS)

- **Startup to health check:** 0.60 s median (3 runs, 0.56–0.59 s)
- **Memory at rest:** 286 MiB RSS / 284 MiB PSS (stable; 306.6 MiB after a test battery)
- **State is memory-only:** SIGTERM removes all resources (verified with marker
  bucket/table, not assumed from docs)
- **Multi-instance:** fully isolated per port
- **Docker:** works with AWS's official procedure (`-b 0.0.0.0` + bridge +
  `-p 127.0.0.1:PORT:PORT`, non-root user) — 9/9 checks incl. LAN isolation
  verified from another machine on the same L2 segment
- **Known fidelity divergences:** DynamoDB `describe_table` omits default attributes
  → provider v6 sees false drift; bucket names strictly validated (uppercase rejected)
- **Historical failures** (already fixed, kept as evidence):
  [`results/01-getting-started/results-historial.json`](results/01-getting-started/results-historial.json)

Measurement methodology:
[`results/01-getting-started/metodologia-medicion.md`](results/01-getting-started/metodologia-medicion.md)

## Editorial series (short articles, ES/EN)

| # | Article (draft titles) | Source lab |
|---|---|---|
| 1 | I tested AWS Emulator, the new official AWS emulator | Lab 01 |
| 2 | AWS Emulator in Docker: problems and solutions | Lab 01 |
| 3 | Does Terraform work with AWS Emulator? | Lab 02 |
| 4 | AWS Emulator vs LocalStack | Labs 01+02 |
| 5 | AWS Emulator and security | Lab 01 |
| 6 | Performance and resource consumption | Lab 01 |

Blog: [cloudsecurityinpractice.com](https://cloudsecurityinpractice.com)

## Contributing / reproducing

1. Fork/clone and run `make setup` on a throwaway VM or container (the bootstrap
   installs system packages with `sudo`).
2. Every experiment writes structured JSON with a unique run ID and ISO-8601
   timestamps; clean-up runs even on failure and only touches resources prefixed
   `aws-emulator-lab-*`.
3. Regenerate stats with `make stats` — totals are never maintained by hand.
4. To test a newer emulator version, change `AWS_EMULATOR_VERSION` (bootstrap) or
   `EMU_VERSION` (Dockerfile), re-run the battery, and record results separately.
5. Pull requests welcome: keep experiments self-contained, fail-closed, and
   resource-prefixed.

## License

Code in this repository: **Apache-2.0** (see [LICENSE](LICENSE) and
[docs/licenses.md](docs/licenses.md) for third-party notices). Blog articles and
course materials are NOT covered by this license. AWS Emulator itself is CC0-1.0
(vendor/ under Apache-2.0) — see AWS's repository for details.

---

### Estructura (ES)

```
labs/     un laboratorio por tema (01 completo, 02 IaC en curso)
scripts/  bootstrap, gestión del emulador, utilidades comunes
docs/     investigación, plan editorial y docs ES/EN
results/  resultados por laboratorio (Markdown + JSON) y evidencias sanitizadas
```

Reglas del proyecto: no se usan credenciales AWS reales; ninguna llamada a AWS real
(endpoints explícitos, cuenta esperada `000000000000`); los resultados distinguen lo
observado en pruebas de lo afirmado por la documentación de AWS.
