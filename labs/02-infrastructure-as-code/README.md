# Lab 02 — Infrastructure as Code against AWS Emulator

> 📖 Artículo en español: [cloudsecurityinpractice.com](https://cloudsecurityinpractice.com) (blog bilingüe ES/EN)

The same logical architecture — **S3 + DynamoDB + SQS** (plus **IAM** where tool
support was validated) — deployed with four IaC tools against AWS Emulator on
`127.0.0.1`. **No AWS account, no AWS credentials, no real cloud resources.**

Reference run: 2026-11-13/14 · Emulator 1.0.341 (re-test 1.0.367) · results in
[`results/02-iac/results.json`](../../results/02-iac/results.json) (normalized v1
schema, English; 37 final tests: 36 PASS + 1 documented FAIL, plus 2 corrected
historical entries kept as evidence).

## Stages

| ID | Tool | Version | What was exercised |
|---|---|---|---|
| I-1 | Terraform | 1.13.3 (SHA-256) | plan / apply (S3+DDB+SQS) / idempotency / deliberate drift / destroy |
| I-2 | Terraform + IAM | 1.13.3 | CreateRole/CreatePolicy/AttachRolePolicy, 7-resource stack, config change, destroy |
| I-3 | OpenTofu | 1.10.5 (SHA-256) | same configuration, drop-in |
| I-4 | CloudFormation | AWS CLI 2.40.2 | create-stack / update-stack / `deploy` via change sets / delete-stack |
| I-5 | CDK | CLI 2.1148.1 + lib 2.214 (Node 20) | synth / bootstrap (15-resource CDKToolkit) / deploy / destroy |
| I-6 | DDB compatibility case | Terraform 1.13.3 | minimal reproducible non-converging drift (re-tested on 1.0.367) |
| I-7 | Network barrier | netns | emulator isolated in a namespace WITHOUT an external route |

## Key findings

1. **Non-converging DynamoDB drift** (`repro/ddb-minimal.main.tf`): a
   `PAY_PER_REQUEST` table without a declared `on_demand_throughput` block →
   the plan proposes emptying it (`[-1,-1] → []`) → apply sends an `UpdateTable`
   with no fields → backend answers `ValidationException` → loop. Identical on
   emulator 1.0.341 and 1.0.367. Root cause lives in `hashicorp/aws` provider
   6.16.0 (schema `Optional` without `Computed`); **not attributable to the
   emulator without comparing against real AWS**. Workaround: declare the block.
   Evidence: [`results/02-iac/evidence/`](../../results/02-iac/evidence/).
2. **Omitting a service from `endpoints{}` sends calls to REAL AWS** (seen with
   IAM: 403 × 25 retries). Three config layers can neutralize this; lab 01's
   guards are still recommended. Negative test in `repro/netns-negative.main.tf`.
3. **Network barrier** (`repro/run-netns-negative.sh`): the emulator runs inside
   a netns with no external route and its own endpoint (`127.0.0.1:9320`);
   with all endpoint layers removed the failure is controlled and local —
   no egress. `ip link set lo up` is required inside the namespace.
4. **CDK bootstrap works**: the emulator serves the full CDKToolkit stack
   (SSM parameter via CloudFormation). The versioned asset bucket needs
   deletion per VersionId + DeleteMarkers on cleanup.
5. **`required_version` pinning**: strict pins belong in the verified
   installation (SHA-256), not in the HCL constraint — an exact `1.13.3` pin
   excluded OpenTofu (historical finding, corrected with `>= 1.6.0`).
6. **`timestamp()` in resource names** → full replacement on every plan. Use a
   persisted `random_id` suffix instead (historical finding, corrected).

## Repository layout

```
terraform/main.tf             # I-1/I-2 reference configuration (S3+DDB+SQS+IAM)
cloudformation/template.yaml  # I-4: sample template (recreated; session original was ad hoc)
cloudformation/run-cfn.sh     # I-4: create → update → deploy (change sets) → delete
cdk/                          # I-5: CDK app (app.ts) + runner script
repro/ddb-minimal.main.tf     # I-6: minimal non-converging drift case
repro/netns-negative.*        # I-7: network barrier + negative IAM test
repro/repro-ddb-describe.sh
../../scripts/netns/          # I-7: independent network barrier (netns, no external route)
../../results/02-iac/         # normalized results + sanitized evidence
```

> Note on I-4: the original experiment session used an ad-hoc template; the
> published `template.yaml` recreates the same logical stack for reproducibility.
> `run-netns-negative.sh` requires `scripts/netns/emulab-netns.sh` from the
> repository root (included since this commit).

## Security notes

- The emulator must stay on `127.0.0.1`. Same guard model as lab 01: local
  endpoint required, emulator credentials, explicit endpoints for every service.
- IAM endpoints are mandatory in `endpoints{}`: a missing entry silently
  targets the real AWS IAM.
- Packages verified (SHA-256 for Terraform/OpenTofu; provider signatures from
  the official registries; emulator GPG for 1.0.367).

See the root [README](../../README.md) for the tested version matrix.
