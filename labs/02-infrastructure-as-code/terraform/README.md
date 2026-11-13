# Lab 02 — IaC con AWS Emulator: Terraform (etapa A)

Arquitectura de referencia mínima: S3 + DynamoDB + SQS (+ IAM cuando se valide cobertura).
Todo contra AWS Emulator en localhost. Nada de AWS real.

## Configuración segura del provider

- Endpoint explícito por servicio (S3/DynamoDB/SQS/STS)
- `ca_bundle` = CA del emulador (TLS autofirmado)
- Credenciales del emulador vía variables (nunca en Git)
- `skip_credentials_validation`, `skip_metadata_api_check`,
  `skip_requesting_account_id` y `s3_use_path_style` necesarios para emulador
- `.terraform/`, `*.tfstate*` y `terraform.tfvars` fuera de Git

## Ejecución

```bash
source ../../scripts/common/env.sh 9297          # credenciales + guard STS del lab
make -C ../.. iac-init iac-plan iac-apply        # o:
cd terraform && terraform init && terraform plan -out=tfplan && terraform apply tfplan
terraform plan -detailed-exitcode                # idempotencia: exit 0 sin cambios
# drift: modificar un recurso con AWS CLI y ver el plan detectarlo
terraform destroy
```

## Pruebas (I-1)

| ID | Prueba | Criterio |
|---|---|---|
| I-1.1 | terraform init + providers instalados | exit 0 |
| I-1.2 | terraform plan (creación) | 3 recursos a crear |
| I-1.3 | terraform apply | exit 0, recursos en el emulador |
| I-1.4 | segundo plan (idempotencia) | exit 0 con -detailed-exitcode, sin cambios |
| I-1.5 | drift (cambio fuera de banda) | plan detecta la diferencia |
| I-1.6 | terraform destroy | exit 0, sin recursos residuales del prefijo |
| I-1.7 | seguridad: sin llamadas a AWS real (endpoint fijado, credenciales locales) | verificación por env scrub + STS check |

## Estado

State local (`terraform.tfstate`, gitignored). El backend remoto (S3 emulado) es
posible pero no recomendado como estado de laboratorio: SIGTERM del emulador borra
el bucket del backend y con él el state. Documentado como limitación.
