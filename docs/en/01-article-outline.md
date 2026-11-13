# Article 01 Outline (EN)

## Proposed title
**AWS Emulator: running AWS's official emulator locally — install and first real tests**

## Structure (based on real lab 01 results)

1. **The problem it solves** — test AWS integrations without an AWS account, cost,
   or risk of hitting real AWS; context: LocalStack owned this niche.
2. **What AWS Emulator is** — official (Sep 2026), Rust, one crate per service,
   measured fidelity published per release.
3. **Installing on Linux** — signed .deb package (GPG verification walkthrough),
   /opt/aws-emulator, first commands. (Evidence: Exp A)
4. **Architecture and how it works** — single HTTPS localhost:9297 endpoint, SigV4,
   per-run ephemeral credentials, in-memory state. (Mermaid diagram)
5. **Configuring CLI and Boto3 safely** — env vars, guardrails against accidental
   real-AWS calls, STS check for account 000000000000.
6. **First tests** — S3/DynamoDB/SQS via CLI and Boto3; PASS/FAIL/PARTIAL table
   with timings. (Evidence: Exp B, C)
7. **Persistence and multi-instance** — what survives a restart (verified,
   not assumed). (Evidence: Exp D)
8. **What about Docker?** — no official image; official-style Dockerfile (AL2023 + verified RPM) with `-b 0.0.0.0`, bridge network and `-p 127.0.0.1:`; the initial v0 failure is narrated as lessons learned (host CPU, gpg-agent, rpm -K) and the verification
   verification. (Evidence: Exp E)
9. **Problems found and solutions** — as documented during the lab.
10. **Advantages and limitations** — fidelity, service coverage, IAM gaps.
11. **Security considerations** — "don't use it to test security" (AWS) and what
    that means: emulated config ≠ enforced controls.
12. **Recommended use cases** and what NOT to do with the emulator.
13. **References** — official docs, repo, consultation dates.

## Suggested metrics
- Summary table (GENERATED via make stats): 40 functional — 35 PASS / 4 FAIL (kept as didactic evidence with root cause) / 1 PARTIAL + 1 documentary observation
- Measured startup time and idle RAM
